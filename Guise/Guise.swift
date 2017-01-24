/*
The MIT License (MIT)

Copyright (c) 2016 Gregory Higley (Prosumma)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import Foundation

/**
 Guise dependency lifecycle.
*/
public enum Lifecycle {
    /**
     The registered block is called on every resolution.
    */
    case notCached
    /**
     The registered block is invoked only once. After that, its cached result is returned.
    */
    case cached
    /**
     The dependency is completely removed after it is resolved the first time.
    */
    case once
}

/**
 `Name.default` is used for the default name of a container or type when one is not specified.
 */
public enum Name {
    /**
     `Name.default` is used for the default name of a container or type when one is not specified.
     */
    case `default`
}

private func hash<H: Hashable>(_ hashables: H...) -> Int {
    // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
    // &+ operator handles Int overflow
    return hashables.reduce(5381) { (result, hashable) in ((result << 5) &+ result) &+ hashable.hashValue }
}

infix operator ??= : AssignmentPrecedence

private func ??=<T>(lhs: inout T?, rhs: @autoclosure () -> T?) {
    if lhs != nil { return }
    lhs = rhs()
}

private class Lock {
    
    private let lock: UnsafeMutablePointer<pthread_rwlock_t> = {
        var lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
        return lock
    }()
    
    private func lock<T>(_ acquire: (UnsafeMutablePointer<pthread_rwlock_t>) -> Int32, block: () -> T) -> T {
        let _ = acquire(lock)
        defer { pthread_rwlock_unlock(lock) }
        return block()
    }
    
    func read<T>(_ block: () -> T) -> T {
        return lock(pthread_rwlock_rdlock, block: block)
    }
    
    func write<T>(_ block: () -> T) -> T {
        return lock(pthread_rwlock_wrlock, block: block)
    }
    
    deinit {
        pthread_rwlock_destroy(lock)
    }
}

/**
 A unique key under which to register a block in Guise.
 
 
*/
public struct Key: Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    
    public init<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) {
        self.type = String(reflecting: T.self)
        self.name = name
        self.container = container
        self.hashValue = hash(self.type, self.name, self.container)
    }
    
    public let hashValue: Int
}

public func ==(lhs: Key, rhs: Key) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.type != rhs.type { return false }
    if lhs.name != rhs.name { return false }
    return true
}

public typealias KeyComparison = (type: String?, name: AnyHashable?, container: AnyHashable?)

public func ==(lhs: Key, rhs: KeyComparison) -> Bool {
    let (type: type, name: name, container: container) = rhs
    if let type = type, lhs.type != type { return false }
    if let name = name, lhs.name != name { return false }
    if let container = container, lhs.container != container { return false }
    if type == nil && name == nil && container == nil { return false }
    return true
}

public func !=(lhs: Key, rhs: KeyComparison) -> Bool {
    return !(lhs == rhs)
}

public typealias Registration<P, T> = (P) -> T

/**
 This class creates and holds a type-erasing thunk over a registration block.
 */
private class Dependency {
    internal let lifecycle: Lifecycle
    
    private let registration: (Any) -> Any
    private var instance: Any?
    
    init<P, T>(lifecycle: Lifecycle, registration: @escaping Registration<P, T>) {
        self.lifecycle = lifecycle
        self.registration = { param in registration(param as! P) }
    }
    
    func resolve<T>(_ parameter: Any, lifecycle: Lifecycle) -> T {
        var result: T
        let lifecycle = lifecycle == .once ? self.lifecycle : lifecycle
        if lifecycle == .cached {
            if instance == nil {
                instance = registration(parameter)
            }
            result = instance! as! T
        } else {
            result = registration(parameter) as! T
        }
        return result
    }
}

public struct Guise {
    private init() {}
    
    private static var lock = Lock()
    private static var registrations = [Key: Dependency]()
    
    private static func register<P, T>(key: Key, lifecycle: Lifecycle = .notCached, registration: @escaping Registration<P, T>) -> Key {
        lock.write { registrations[key] = Dependency(lifecycle: lifecycle, registration: registration) }
        return key
    }
    
    /**
     Register the `registration` block with Guise under the given name and in the given container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - name: The name under which to register the block.
        - container: The container in which to register the block.
        - lifecycle: The lifecycle of the block. See `Lifecycle` for a more in-depth discussion.
        - registration: The block to register with Guise.
    */
    public static func register<P, T, N: Hashable, C: Hashable>(name: N, container: C, lifecycle: Lifecycle = .notCached, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: name, container: container), lifecycle: lifecycle, registration: registration)
    }

    public static func register<P, T, N: Hashable>(name: N, lifecycle: Lifecycle = .notCached, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: name, container: Name.default), lifecycle: lifecycle, registration: registration)
    }
    
    public static func register<P, T, C: Hashable>(container: C, lifecycle: Lifecycle = .notCached, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: container), lifecycle: lifecycle, registration: registration)
    }
    
    public static func register<P, T>(lifecycle: Lifecycle = .notCached, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), lifecycle: lifecycle, registration: registration)
    }
    
    public static func register<T, N: Hashable, C: Hashable>(instance: T, name: N, container: C, lifecycle: Lifecycle = .cached) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), lifecycle: lifecycle) { instance }
    }
    
    public static func register<T, N: Hashable>(instance: T, name: N, lifecycle: Lifecycle = .cached) -> Key {
        return register(key: Key(type: T.self, name: name, container: Name.default), lifecycle: lifecycle) { instance }
    }
    
    public static func register<T, C: Hashable>(instance: T, container: C, lifecycle: Lifecycle = .cached) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: container), lifecycle: lifecycle) { instance }
    }
    
    public static func register<T>(instance: T, lifecycle: Lifecycle = .cached) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), lifecycle: lifecycle) { instance }
    }
    
    public static func resolve<T>(key: Key, parameter: Any = (), lifecycle: Lifecycle? = nil) -> T? {
        guard let dependency = lock.read({ registrations[key] }) else { return nil }
        let lifecycle = lifecycle ?? dependency.lifecycle
        defer {
            if lifecycle == .once { clear(key: key) }
        }
        return dependency.resolve(parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<T, N: Hashable, C: Hashable>(name: N, container: C, parameter: Any = (), lifecycle: Lifecycle? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: container), parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<T, N: Hashable>(name: N, parameter: Any = (), lifecycle: Lifecycle? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: Name.default), parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<T, C: Hashable>(container: C, parameter: Any = (), lifecycle: Lifecycle? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: container), parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<T>(parameter: Any = (), lifecycle: Lifecycle? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: Name.default), parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func getKeyComparison<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) -> KeyComparison {
        return (type: String(reflecting: T.self), name: name, container: container)
    }
    
    public static func getKeyComparison<T, N: Hashable>(type: T.Type, name: N) -> KeyComparison {
        return (type: String(reflecting: T.self), name: name, container: nil)
    }
    
    public static func getKeyComparison<T, C: Hashable>(type: T.Type, container: C) -> KeyComparison {
        return (type: String(reflecting: T.self), name: nil, container: container)
    }
    
    public static func getKeyComparison<N: Hashable, C: Hashable>(name: N, container: C) -> KeyComparison {
        return (type: nil, name: name, container: container)
    }
    
    public static func getKeyComparison<T>(type: T.Type) -> KeyComparison {
        return (type: String(reflecting: T.self), name: nil, container: nil)
    }
    
    public static func getKeyComparison<N: Hashable>(name: N) -> KeyComparison {
        return (type: nil, name: name, container: nil)
    }
    
    public static func getKeyComparison<C: Hashable>(container: C) -> KeyComparison {
        return (type: nil, name: nil, container: container)
    }
    
    public static func clear(key: Key) {
        return lock.write { registrations.removeValue(forKey: key) }
    }
    
    public static func clear(_ isExcluded: (Key) -> Bool) {
        return lock.write{ registrations = registrations.filter{ !isExcluded($0.key) }.dictionary{ $0 } }
    }
    
    public static func clear<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) {
        clear{ $0 == getKeyComparison(type: type, name: name, container: container) }
    }
    
    public static func clear<T, N: Hashable>(type: T.Type, name: N) {
        clear{ $0 == getKeyComparison(type: type, name: name) }
    }
    
    public static func clear<T, C: Hashable>(type: T.Type, container: C) {
        clear{ $0 == getKeyComparison(type: type, container: container) }
    }
    
    public static func clear<N: Hashable, C: Hashable>(name: N, container: C) {
        clear{ $0 == getKeyComparison(name: name, container: container) }
    }
        
    public static func clear<T>(type: T.Type) {
        clear{ $0 == getKeyComparison(type: type) }
    }
    
    public static func clear<N: Hashable>(name: N) {
        clear{ $0 == getKeyComparison(name: name) }
    }
    
    public static func clear<C: Hashable>(container: C) {
        clear{ $0 == getKeyComparison(container: container) }
    }
}

extension Array {
    func dictionary<K: Hashable, V>(transform: (Element) -> (key: K, value: V)) -> [K: V] {
        var dictionary = [K: V]()
        for element in self {
            let entry = transform(element)
            dictionary[entry.key] = entry.value
        }
        return dictionary
    }
}
