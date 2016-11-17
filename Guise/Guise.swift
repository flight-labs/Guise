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

public struct Key: Hashable {
    fileprivate let type: String
    fileprivate let name: AnyHashable
    fileprivate let container: AnyHashable
    
    init<D, C: Hashable, N: Hashable>(type: D.Type, container: C, name: N) {
        self.type = String(reflecting: D.self)
        self.name = name
        self.container = container
        // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
        // &+ operator handles Int overflow
        var hash = 5381
        hash = ((hash << 5) &+ hash) &+ self.type.hashValue
        hash = ((hash << 5) &+ hash) &+ self.container.hashValue
        hash = ((hash << 5) &+ hash) &+ self.name.hashValue
        hashValue = hash
    }
    
    init<P, D, C: Hashable, N: Hashable>(container: C, name: N, resolve: (P) -> D) {
        self.init(type: D.self, container: container, name: name)
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

internal class Dependency {
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

enum Name {
    case `default`
}

enum Container {
    case `default`
}

public struct Guise {
    
    // MARK: Locking
    // Inspired by some of John Gallagher's locking code in the excellent Deferred library at https://github.com/bignerdranch/Deferred
    
    private static var lock: UnsafeMutablePointer<pthread_rwlock_t> = {
        var lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
        return lock
    }()
    
    private static func withLock<T>(_ acquire: (UnsafeMutablePointer<pthread_rwlock_t>) -> Int32, block: () -> T) -> T {
        let _ = acquire(lock)
        defer { pthread_rwlock_unlock(lock) }
        return block()
    }
    
    private static func withReadLock<T>(_ block: () -> T) -> T {
        return withLock(pthread_rwlock_rdlock, block: block)
    }
    
    private static func withWriteLock<T>(_ block: () -> T) -> T {
        return withLock(pthread_rwlock_wrlock, block: block)
    }
    
    private static var dependencies = [Key: Dependency]()
    
    public static func register<P, D, C: Hashable, N: Hashable>(container: C, name: N, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        let key = Key(type: D.self, container: container, name: name)
        withWriteLock {
            dependencies[key] = Dependency(lifecycle: lifecycle, resolve: resolve)
        }
        return key
    }
    
    public static func register<P, D, N: Hashable>(name: N, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(container: Container.default, name: name, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func register<P, D, C: Hashable>(container: C, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(container: container, name: Container.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func register<P, D>(lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return register(container: Container.default, name: Name.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public static func unregister(key: Key) {
        let _ = withWriteLock { dependencies.removeValue(forKey: key) }
    }
    
    public static func unregister<D, C: Hashable, N: Hashable>(type: D.Type, container: C, name: N) {
        let key = Key(type: D.self, container: container, name: name)
        unregister(key: key)
    }
    
    public static func unregister<D, C: Hashable>(type: D.Type, container: C) {
        let key = Key(type: D.self, container: container, name: Name.default)
        unregister(key: key)
    }
    
    public static func unregister<D, N: Hashable>(type: D.Type, name: N) {
        let key = Key(type: D.self, container: Container.default, name: name)
        unregister(key: key)
    }
    
    public static func unregister<D>(type: D.Type) {
        
    }
    
    public static func container<C: Hashable>(name: C, lifecycle: Lifecycle = .notCached) -> Guise {
        return Guise(name: name, lifecycle: lifecycle)
    }
    
    public static func resolve<D>(key: Key, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        guard let dependency = withReadLock({ dependencies[key] }) else { return nil }
        if lifecycle == .once || dependency.lifecycle == .once {
            let _ = withWriteLock { dependencies.removeValue(forKey: key) }
        }
        return (dependency.resolve(parameter, lifecycle: lifecycle) as D)
    }
    
    public static func resolve<D, C: Hashable, N: Hashable>(container: C, name: N, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        let key = Key(type: D.self, container: container, name: name)
        return resolve(key: key, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D, C: Hashable>(container: C, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(container: container, name: Name.default, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D, N: Hashable>(name: N, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(container: Container.default, name: name, parameter: parameter, lifecycle: lifecycle)
    }
    
    public static func resolve<D>(parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return resolve(container: Container.default, name: Name.default, parameter: parameter, lifecycle: lifecycle)
    }
    
    public let name: AnyHashable
    public let lifecycle: Lifecycle
    
    public init<C: Hashable>(name: C, lifecycle: Lifecycle = .notCached) {
        self.name = name
        self.lifecycle = lifecycle
    }
    
    public func register<P, D, C: Hashable, N: Hashable>(container: C, name: N, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(container: container, name: name, lifecycle: lifecycle, resolve: resolve)
    }
    
    public func register<P, D, N: Hashable>(name: N, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(container: Container.default, name: name, lifecycle: lifecycle, resolve: resolve)
    }
    
    public func register<P, D, C: Hashable>(container: C, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(container: container, name: Container.default, lifecycle: lifecycle, resolve: resolve)
    }
    
    public func register<P, D>(lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        return Guise.register(container: Container.default, name: Name.default, lifecycle: lifecycle, resolve: resolve)
    }

    public func resolve<D>(key: Key, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return Guise.resolve(key: key, parameter: parameter, lifecycle: lifecycle)
    }
    
    public func resolve<D, C: Hashable, N: Hashable>(container: C, name: N, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        let key = Key(type: D.self, container: container, name: name)
        return Guise.resolve(key: key, parameter: parameter, lifecycle: lifecycle)
    }
    
    public func resolve<D, C: Hashable>(container: C, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return Guise.resolve(container: container, name: Name.default, parameter: parameter, lifecycle: lifecycle)
    }
    
    public func resolve<D, N: Hashable>(name: N, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return Guise.resolve(container: Container.default, name: name, parameter: parameter, lifecycle: lifecycle)
    }
    
    public func resolve<D>(parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        return Guise.resolve(container: Container.default, name: Name.default, parameter: parameter, lifecycle: lifecycle)
    }

}
