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

public func ==(lhs: KeyComparison, rhs: Key) -> Bool {
    return rhs == lhs
}

public func !=(lhs: Key, rhs: KeyComparison) -> Bool {
    return !(lhs == rhs)
}

public func !=(lhs: KeyComparison, rhs: Key) -> Bool {
    return !(lhs == rhs)
}

public typealias Registration<P, T> = (P) -> T

/**
 This class creates and holds a type-erasing thunk over a registration block.
 */
private class Dependency {
    /** Default lifecycle for the dependency. */
    internal let cached: Bool
    /** Registered block. */
    private let registration: (Any) -> Any
    /** Cached instance, if any. */
    private var instance: Any?
    
    init<P, T>(cached: Bool, registration: @escaping Registration<P, T>) {
        self.cached = cached
        self.registration = { param in registration(param as! P) }
    }
    
    func resolve<T>(parameter: Any, cached: Bool) -> T {
        var result: T
        if cached {
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
    
    /**
     Register the `registration` block with Guise using the given key.
     
     - returns: The key passed to it.
     
     - parameters:
        - key: The key with which to register.
        - cached: Whether or not to cache the result of the registration block.
        - registration: The block to register with Guise.
    */
    private static func register<P, T>(key: Key, cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        lock.write { registrations[key] = Dependency(cached: cached, registration: registration) }
        return key
    }
    
    /**
     Register the `registration` block with Guise under the given name and in the given container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - name: The name under which to register the block.
        - container: The container in which to register the block.
        - cached: Whether or not to cache the result of the registration block.
        - registration: The block to register with Guise.
    */
    public static func register<P, T, N: Hashable, C: Hashable>(name: N, container: C, cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: name, container: container), cached: cached, registration: registration)
    }

    /**
     Register the `registration` block with Guise under the given name and in the default container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - name: The name under which to register the block.
        - cached: Whether or not to cache the result of the registration block.
        - registration: The block to register with Guise.
    */
    public static func register<P, T, N: Hashable>(name: N, cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: name, container: Name.default), cached: cached, registration: registration)
    }
    
    /**
     Register the `registration` block with Guise with the default name in the given container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
         - container: The container in which to register the block.
         - cached: Whether or not to cache the result of the registration block.
         - registration: The block to register with Guise.
    */
    public static func register<P, T, C: Hashable>(container: C, cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: container), cached: cached, registration: registration)
    }

    /**
     Register the `registration` block with Guise with the default name in the default container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
         - cached: Whether or not to cache the result of the registration block.
         - registration: The block to register with Guise.
    */
    public static func register<P, T>(cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), cached: cached, registration: registration)
    }
    
    /**
     Register the given instance with the specified name and in the specified container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - instance: The instance to register.
        - name: The name under which to register the block.
        - container: The container in which to register the block.
    */
    public static func register<T, N: Hashable, C: Hashable>(instance: T, name: N, container: C) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), cached: true) { instance }
    }
    
    public static func register<T, N: Hashable>(instance: T, name: N) -> Key {
        return register(key: Key(type: T.self, name: name, container: Name.default), cached: true) { instance }
    }
    
    public static func register<T, C: Hashable>(instance: T, container: C) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: container), cached: true) { instance }
    }
    
    public static func register<T>(instance: T) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), cached: true) { instance }
    }
    
    public static func resolve<T>(key: Key, parameter: Any = (), cached: Bool? = nil) -> T? {
        guard let dependency = lock.read({ registrations[key] }) else { return nil }
        return dependency.resolve(parameter: parameter, cached: cached ?? dependency.cached)
    }
    
    public static func resolve<T, N: Hashable, C: Hashable>(name: N, container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: container), parameter: parameter, cached: cached)
    }
    
    public static func resolve<T, N: Hashable>(name: N, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: Name.default), parameter: parameter, cached: cached)
    }
    
    public static func resolve<T, C: Hashable>(container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: container), parameter: parameter, cached: cached)
    }
    
    public static func resolve<T>(parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: Name.default), parameter: parameter, cached: cached)
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
    
    public static func unregister(key: Key) {
        return lock.write { registrations.removeValue(forKey: key) }
    }
    
    public static func unregister(_ isExcluded: (Key) -> Bool) {
        return lock.write{ registrations = registrations.filter{ !isExcluded($0.key) }.dictionary{ $0 } }
    }
    
    public static func unregister<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) {
        unregister{ $0 == getKeyComparison(type: type, name: name, container: container) }
    }
    
    public static func unregister<T, N: Hashable>(type: T.Type, name: N) {
        unregister{ $0 == getKeyComparison(type: type, name: name) }
    }
    
    public static func unregister<T, C: Hashable>(type: T.Type, container: C) {
        unregister{ $0 == getKeyComparison(type: type, container: container) }
    }
    
    public static func unregister<N: Hashable, C: Hashable>(name: N, container: C) {
        unregister{ $0 == getKeyComparison(name: name, container: container) }
    }
        
    public static func unregister<T>(type: T.Type) {
        unregister{ $0 == getKeyComparison(type: type) }
    }
    
    public static func unregister<N: Hashable>(name: N) {
        unregister{ $0 == getKeyComparison(name: name) }
    }
    
    public static func unregister<C: Hashable>(container: C) {
        unregister{ $0 == getKeyComparison(container: container) }
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
