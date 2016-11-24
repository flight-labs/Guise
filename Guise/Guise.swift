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

private func hash<H: Hashable>(_ hashables: H...) -> Int {
    // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
    // &+ operator handles Int overflow
    return hashables.reduce(5381) { (result, hashable) in ((result << 5) &+ result) &+ hashable.hashValue }
}

infix operator ??= : AssignmentPrecedence

func ??=<T>(lhs: inout T?, rhs: @autoclosure () -> T?) {
    if lhs != nil { return }
    lhs = rhs()
}

/**
 The key representing a registered dependency.
 */
public struct Key: Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    
    public init<D, N: Hashable, C: Hashable>(type: D.Type, name: N, container: C) {
        self.type = String(reflecting: D.self)
        self.name = name
        self.container = container
        hashValue = hash(self.type, self.name, self.container)
    }
    
    public let hashValue: Int
}

public func ==(lhs: Key, rhs: Key) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.type != rhs.type { return false }
    if lhs.name != rhs.name { return false }
    if lhs.container != rhs.container { return false }
    return true
}

class Dependency {
    internal let lifecycle: Lifecycle
    
    private let resolve: (Any) -> Any
    private var instance: Any?
    
    init<P, D>(lifecycle: Lifecycle, resolve: @escaping (P) -> D) {
        self.lifecycle = lifecycle
        self.resolve = { param in resolve(param as! P) }
    }
    
    func resolve<D>(_ parameter: Any, lifecycle: Lifecycle) -> D {
        var result: D
        if lifecycle != .notCached && self.lifecycle == .cached {
            if instance == nil {
                instance = resolve(parameter)
            }
            result = instance! as! D
        } else {
            result = resolve(parameter) as! D
        }
        return result
    }
}

public enum Name {
    case `default`
}

// MARK: Locking
// Inspired by some of John Gallagher's locking code in the excellent Deferred library at https://github.com/bignerdranch/Deferred
struct Lock {
    private var lock: UnsafeMutablePointer<pthread_rwlock_t> = {
        var lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
        return lock
    }()
    
    func with<T>(_ acquire: (UnsafeMutablePointer<pthread_rwlock_t>) -> Int32, block: () -> T) -> T {
        let _ = acquire(lock)
        defer { pthread_rwlock_unlock(lock) }
        return block()
    }
    
    func read<T>(_ block: () -> T) -> T {
        return with(pthread_rwlock_rdlock, block: block)
    }
    
    func write<T>(_ block: () -> T) -> T {
        return with(pthread_rwlock_wrlock, block: block)
    }
}

struct DependencyStore {
    private var lock = Lock()
    private var dependencies = [Key: Dependency]()
    private var containers = [AnyHashable: Set<Key>]()
    
    mutating func updateDependency(_ dependency: Dependency?, forKey key: Key) {
        lock.write {
            dependencies[key] = dependency
            if dependency != nil {
                containers[key.container] ??= Set<Key>()
                containers[key.container]!.insert(key)
            } else {
                let _ = containers[key.container]?.remove(key)
                if let keys = containers[key.container], keys.count == 0 {
                    containers.removeValue(forKey: key.container)
                }
            }
        }
    }
    
    mutating func removeDependency(forKey key: Key) {
        lock.write {
            dependencies.removeValue(forKey: key)
            let _ = containers[key.container]?.remove(key)
        }
    }
    
    mutating func clear() {
        lock.write {
            dependencies = [:]
            containers = [:]
        }
    }
    
    mutating func clear<C: Hashable>(container: C) {
        clear(hashable: container)
    }
    
    mutating func clear(hashable: AnyHashable) {
        lock.write {
            guard let keys = containers[hashable] else { return }
            keys.forEach { dependencies.removeValue(forKey: $0) }
            containers[hashable] = nil
            containers.removeValue(forKey: hashable)
        }
    }
    
    subscript(key: Key) -> Dependency? {
        get { return lock.read { dependencies[key] } }
        set { updateDependency(newValue, forKey: key) }
    }
}

public struct Guise {
    
    fileprivate static var dependencyStore = DependencyStore()
    
    public static func register<P, D, N: Hashable, C: Hashable>(name: N, container: C, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        let key = Key(type: D.self, name: name, container: container)
        let dependency = Dependency(lifecycle: lifecycle, resolve: resolve)
        dependencyStore[key] = dependency
        return key
    }
    
    public static func register<P, D, N: Hashable>(name: N, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(name: name, container: Name.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func register<P, D, C: Hashable>(container: C, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(name: Name.default, container: Name.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func register<P, D>(lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(name: Name.default, container: Name.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func register<D, N: Hashable, C: Hashable>(instance: D, name: N, container: C, lifecycle: Lifecycle = .cached) -> Key {
        return register(name: name, container: container, lifecycle: lifecycle) { instance }
    }
    
    public static func register<D, N: Hashable>(instance: D, name: N, lifecycle: Lifecycle = .cached) -> Key {
        return register(instance: instance, name: name, container: Name.default, lifecycle: lifecycle)
    }
    
    public static func register<D, C: Hashable>(instance: D, container: C, lifecycle: Lifecycle = .cached) -> Key {
        return register(instance: instance, name: Name.default, container: container, lifecycle: lifecycle)
    }
    
    public static func register<D>(instance: D, lifecycle: Lifecycle = .cached) -> Key {
        return register(instance: instance, name: Name.default, container: Name.default, lifecycle: lifecycle)
    }
    
    public static func unregister(key: Key) {
        dependencyStore[key] = nil
    }
    
    public static func unregister<D, N: Hashable, C: Hashable>(type: D.Type, name: N, container: C) {
        let key = Key(type: D.self, name: name, container: container)
        unregister(key: key)
    }
    
    public static func unregister<D, C: Hashable>(type: D.Type, container: C) {
        let key = Key(type: D.self, name: Name.default, container: container)
        unregister(key: key)
    }
    
    public static func unregister<D, N: Hashable>(type: D.Type, name: N) {
        let key = Key(type: D.self, name: name, container: Name.default)
        unregister(key: key)
    }
    
    public static func unregister<D>(type: D.Type) {
        let key = Key(type: D.self, name: Name.default, container: Name.default)
        unregister(key: key)
    }
    
    public static func container<C: Hashable>(name: C, lifecycle: Lifecycle = .notCached) -> Container {
        return Container(name: name, lifecycle: lifecycle)
    }
    
    public static func resolve<D>(key: Key, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        guard let dependency = dependencyStore[key] else { return nil }
        if lifecycle == .once || dependency.lifecycle == .once {
            unregister(key: key)
        }
        return (dependency.resolve(parameter, lifecycle: lifecycle) as D)
    }
    
    public static func resolve<D, N: Hashable, C: Hashable>(name: N, container: C, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        let key = Key(type: D.self, name: name, container: container)
        return resolve(key: key, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D, C: Hashable>(container: C, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(name: Name.default, container: container, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D, N: Hashable>(name: N, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(name: name, container: Name.default, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D>(parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(name: Name.default, container: Name.default, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func clear() {
        dependencyStore.clear()
    }
    
    public static func clear<C: Hashable>(container: C) {
        dependencyStore.clear(container: container)
    }
    
}

public struct Container {
    public let name: AnyHashable
    public let lifecycle: Lifecycle
    
    fileprivate init<C: Hashable>(name: C, lifecycle: Lifecycle = .notCached) {
        self.name = name
        self.lifecycle = lifecycle
    }
    
    public func register<P, D, N: Hashable>(name: N, lifecycle: Lifecycle? = nil, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(name: name, container: self.name, lifecycle: lifecycle ?? self.lifecycle, resolve: resolve)
    }
    
    public func register<P, D>(lifecycle: Lifecycle? = nil, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(name: Name.default, container: self.name, lifecycle: lifecycle ?? self.lifecycle, resolve: resolve)
    }
    
    public func unregister(key: Key) {
        Guise.unregister(key: key)
    }
    
    public func unregister<D>(type: D.Type) {
        let key = Key(type: D.self, name: Name.default, container: self.name)
        Guise.unregister(key: key)
    }
    
    public func unregister<D, N: Hashable>(type: D.Type, name: N) {
        let key = Key(type: D.self, name: name, container: self.name)
        Guise.unregister(key: key)
    }
    
    public func resolve<D, N: Hashable>(name: N, parameter: Any = (), lifecycle: Lifecycle? = nil) -> D? {
        let key = Key(type: D.self, name: name, container: self.name)
        return Guise.resolve(key: key, parameter: parameter, lifecycle: lifecycle ?? self.lifecycle)
    }
    
    public func resolve<D>(parameter: Any = (), lifecycle: Lifecycle? = nil) -> D? {
        let key = Key(type: D.self, name: Name.default, container: self.name)
        return Guise.resolve(key: key, parameter: parameter, lifecycle: lifecycle ?? self.lifecycle)
    }
    
    public func clear() {
        Guise.dependencyStore.clear(hashable: self.name)
    }
}

