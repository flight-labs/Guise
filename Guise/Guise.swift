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
 A simple, elegant, flexible dependency resolver.
 
 Registration uses a `type` and an optional `name`. The combination
 of `type` and `name` must be unique. Registering the same `type`
 and `name` **overwrites** the previous registration.
 */
public struct Guise {
    
    fileprivate init() {}
    
    // MARK: Dependencies

    /**
     A type-erasing thunk over the `resolve` block, with metadata.
    */
    fileprivate class Dependency {
        fileprivate let resolve: (Any) -> Any
        fileprivate let lifecycle: Lifecycle
        fileprivate var instance: Any?
        
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
    
    fileprivate static var dependencies = [Key: Dependency]()
    
    // MARK: Locking
    // Inspired by some of John Gallagher's locking code in the excellent Deferred library at https://github.com/bignerdranch/Deferred
    
    fileprivate static var lock: UnsafeMutablePointer<pthread_rwlock_t> = {
        var lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
        return lock
    }()
    
    fileprivate static func withLock<T>(_ acquire: (UnsafeMutablePointer<pthread_rwlock_t>) -> Int32, block: () -> T) -> T {
        let _ = acquire(lock)
        defer { pthread_rwlock_unlock(lock) }
        return block()
    }
    
    fileprivate static func withReadLock<T>(_ block: () -> T) -> T {
        return withLock(pthread_rwlock_rdlock, block: block)
    }
    
    fileprivate static func withWriteLock<T>(_ block: () -> T) -> T {
        return withLock(pthread_rwlock_wrlock, block: block)
    }
    
    // MARK: Registration
    
    /**
     Registers the block `resolve` with Guise.
     
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter container: A named container into which to place the dependency.
     - parameter lifecycle: The lifecyle of the registered dependency.
     - parameter resolve: The block to register with Guise.
     
     - returns: The registration key, which can be used with `unregister`.
     
     - warning: It is strongly recommended that the generic parameter `D` is not an optional.
     */
    public static func register<P, D>(type: String = String(reflecting: D.self), name: String? = nil, container: String? = nil, lifecycle: Lifecycle = .notCached, resolve: @escaping (P) -> D) -> Key {
        let key = Key(type: type, name: name, container: container, resolve: resolve)
        withWriteLock {
            dependencies[key] = Dependency(lifecycle: lifecycle, resolve: resolve)
        }
        return key
    }
    
    /**
     Registers an existing instance with Guise.
     
     - note: This effectively creates a singleton. If you want your singleton created lazily,
     register it with a block and set `lifecycle` to `.Cached`.
     
     - parameter instance: The instance to register.
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate the same `type`.
     - parameter container: A named container into which to place the dependency.
     
     - returns: The registration key, which can be used with `unregister`.
     
     - warning: It is strongly recommended that the generic parameter `D` is not an optional.
     */
    public static func register<D>(_ instance: D, type: String = String(reflecting: D.self), name: String? = nil, container: String? = nil) -> Key {
        return register(type: type, name: name, container: container, lifecycle: .cached) { instance }
    }
    
    /**
     Unregisters the dependency with the given key.
     */
    public static func unregister(_ key: Key) -> Bool {
        return withWriteLock { dependencies.removeValue(forKey: key) != nil }
    }
    
    /**
     Unregisters the dependency with the given type and name.
     
     - parameter type: The type of the dependency to unregister.
     - parameter name: The name of the dependency to unregister (optional).
     */
    public static func unregister(type: String, name: String? = nil, container: String? = nil) -> Bool {
        let key = Key(type: type, name: name, container: container)
        return unregister(key)
    }
    
    /**
     Unregisters the dependency with the given name and type, as determined by the `resolve` block.
     
     - parameter name: The optional name under which the dependency was registered.
     - parameter resolve: A block (not called) used to determine the type that was registered.
     
     - note: The block is never called. It is only used to determine the type used to
     originally register the block. The block can take a parameter just like the registration
     block, but it is ignored.
     */
    public static func unregister<P, D>(name: String? = nil, container: String? = nil, resolve: (P) -> D) -> Bool {
        return unregister(type: String(reflecting: D.self), name: name, container: container)
    }
    
    // MARK: Resolution
    
    /**
     Resolves an instance of `D` in Guise.
     
     - parameter key: The key with which `D` was registered.
     - parameter lifecycle: The desired lifecyle of the registered dependency.
     
     - returns: The result of the registered block, or nil if not registered.
     
     - note: The meaning of `lifecycle` here is a bit complex. If `.Once` is passed, the dependency is returned and
     then immediately unregistered, regardless of how it was originally registered. If `.Cached` (the default) is passed and
     the dependency was originally registered with `.Cached`, a cached a value is returned. If `.NotCached` is passed and the
     dependency was originally registered with `.Cached`, the cached value is ignored and a new value is calculated. In all
     other cases, a new value is calculated by invoking the registered block.
    */
    public static func resolve<D>(_ key: Key, parameter: Any = (), lifecycle: Lifecycle = .cached) -> D? {
        guard let dependency = withReadLock({ dependencies[key] }) else { return nil }
        if lifecycle == .once || dependency.lifecycle == .once {
            let _ = withWriteLock { dependencies.removeValue(forKey: key) }
        }
        return (dependency.resolve(parameter, lifecycle: lifecycle) as D)
    }
    
    /**
     Resolves an instance of `D` in Guise.
     
     - parameter parameter: The parameter to pass to the registered block.
     - parameter type: Usually the type of `D`, can be any string.
     - parameter name: An optional name to disambiguate the same `type`.
     - parameter container: The dependency's registered container.
     - parameter lifecycle: The desired lifecyle of the registered dependency.
     
     - returns: The result of the registered block, or nil if not registered.
     
     - note: The meaning of `lifecycle` here is a bit complex. If `.Once` is passed, the dependency is returned and
     then immediately unregistered, regardless of how it was originally registered. If `.Cached` (the default) is passed and
     the dependency was originally registered with `.Cached`, a cached a value is returned. If `.NotCached` is passed and the
     dependency was originally registered with `.Cached`, the cached value is ignored and a new value is calculated. In all
     other cases, a new value is calculated by invoking the registered block.
     */
    public static func resolve<D>(_ parameter: Any = (), type: String = String(reflecting: D.self), name: String? = nil, container: String? = nil, lifecycle: Lifecycle = .cached) -> D? {
        let key = Key(type: type, name: name, container: container)
        return resolve(key, parameter: parameter, lifecycle: lifecycle)
    }
    
    // MARK: Reset
    
    /**
     Clears all dependencies from Guise.
    */
    public static func reset() {
        withWriteLock { dependencies = [:] }
    }
    
    /**
     Clears all dependencies in the given container from Guise.
    */
    public static func reset(_ container: String?) {
        withWriteLock {
            for key in dependencies.keys {
                if key.container == container {
                    dependencies.removeValue(forKey: key)
                }
            }
        }
    }
    
    // MARK: Containers
    
    public static func container(_ name: String?, lifecycle: Lifecycle = .notCached) -> Container {
        return Container(name: name, lifecycle: lifecycle)
    }
}

// MARK: - Keys

public struct Key: Hashable {
    public let container: String?
    public let type: String
    public let name: String?
    
    public init(type: String, name: String? = nil, container: String? = nil) {
        self.type = type
        self.name = name
        self.container = container
        // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
        // &+ operator handles Int overflow
        var hash = 5381
        hash = ((hash << 5) &+ hash) &+ type.hashValue
        if let name = name {
            hash = ((hash << 5) &+ hash) &+ name.hashValue
        }
        if let container = container {
            hash = ((hash << 5) &+ hash) &+ container.hashValue
        }
        hashValue = hash
    }
    
    public init<P, D>(type: String = String(reflecting: D.self), name: String? = nil, container: String? = nil, resolve: (P) -> D) {
        self.init(type: type, name: name, container: container)
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

// MARK: - Containers

public struct Container {
    
    public let container: String?
    public let lifecycle: Lifecycle
    
    fileprivate init(name: String?, lifecycle: Lifecycle) {
        self.container = name
        self.lifecycle = lifecycle
    }
    
    // MARK: Registration
    
    /**
     Registers the block `resolve` in the current Guise container.
     
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter lifecycle: The lifecyle of the registered dependency.
     - parameter resolve: The block to register with Guise.
     
     - returns: The registration key, which can be used with `unregister`.
     
     - warning: It is strongly recommended that the generic parameter `D` is not an optional.
     */
    public func register<P, D>(type: String = String(reflecting: D.self), name: String? = nil, lifecycle: Lifecycle? = nil, resolve: @escaping (P) -> D) -> Any {
        return Guise.register(type: type, name: name, container: container, lifecycle: lifecycle ?? self.lifecycle, resolve: resolve)
    }
    
    /**
     Registers an existing instance in the current Guise container.
     
     - note: This effectively creates a singleton. If you want your singleton created lazily,
     register it with a block and set `lifecycle` to `.Cached`.
     
     - parameter instance: The instance to register.
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate the same `type`.
     
     - returns: The registration key, which can be used with `unregister`.
     
     - warning: It is strongly recommended that the generic parameter `D` is not an optional.
     */
    public func register<D>(_ instance: D, type: String = String(reflecting: D.self), name: String? = nil) -> Any {
        return register(type: type, name: name, lifecycle: .cached) { instance }
    }
    
    /**
     Unregisters the dependency with the given type and name from the current Guise container.
     
     - parameter type: The type of the dependency to unregister.
     - parameter name: The name of the dependency to unregister (optional).
     */
    public func unregister(type: String, name: String? = nil) -> Bool {
        return Guise.unregister(type: type, name: name, container: container)
    }
    
    /**
     Unregisters the dependency with the given name and type, as determined by the `resolve` block,
     from the current Guise container.
     
     - parameter name: The optional name under which the dependency was registered.
     - parameter resolve: A block (not called) used to determine the type that was registered.
     
     - returns: Whether or not the key was present and could be unregistered.
     
     - note: The block is never called. It is only used to determine the type used to
     originally register the block. The block can take a parameter just like the registration
     block, but it is ignored.
     */
    public func unregister<P, D>(name: String? = nil, resolve: (P) -> D) -> Bool {
        return Guise.unregister(name: name, container: container, resolve: resolve)
    }
    
    // MARK: Resolution
    
    /**
     Resolves an instance of `D` in the current Guise container.
     
     - parameter parameter: The parameter to pass to the registered block.
     - parameter type: Usually the type of `D`, can be any string.
     - parameter name: An optional name to disambiguate the same `type`.
     - parameter lifecycle: The desired lifecyle of the registered dependency.
     
     - returns: The result of the registered block, or nil if not registered.
     
     - note: The meaning of `lifecycle` here is a bit complex. If `.Once` is passed, the dependency is returned and
     then immediately unregistered, regardless of how it was originally registered. If `.Cached` (the default) is passed and
     the dependency was originally registered with `.Cached`, a cached a value is returned. If `.NotCached` is passed and the
     dependency was originally registered with `.Cached`, the cached value is ignored and a new value is calculated. In all
     other cases, a new value is calculated by invoking the registered block.
     */
    public func resolve<D>(_ parameter: Any, type: String = String(reflecting: D.self), name: String? = nil, lifecycle: Lifecycle = .cached) -> D? {
        return Guise.resolve(parameter, type: type, name: name, container: container, lifecycle: lifecycle)
    }
    
    /**
     Resolves an instance of `D` in the current Guise container.
     
     - parameter type: Usually the type of `D`, can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter lifecycle: The desired lifecycle of the registered dependency.
     
     - returns: The result of the registered block, or nil if not registered.
     
     - note: The meaning of `lifecycle` here is a bit complex. If `.Once` is passed, the dependency is returned and
     then immediately unregistered, regardless of how it was originally registered. If `.Cached` (the default) is passed and
     the dependency was originally registered with `.Cached`, a cached a value is returned. If `.NotCached` is passed and the
     dependency was originally registered with `.Cached`, the cached value is ignored and a new value is calculated. In all
     other cases, a new value is calculated by invoking the registered block.
     */
    public func resolve<D>(type: String = String(reflecting: D.self), name: String? = nil, lifecycle: Lifecycle = .cached) -> D? {
        return resolve((), type: type, name: name, lifecycle: lifecycle)
    }
    
    // MARK: Reset
    
    /**
     Clears all dependencies in this container from Guise.
     */
    public func reset() {
        Guise.reset(container)
    }
    
    // MARK: Keys

    public func key(type: String, name: String? = nil) -> Key {
        return Key(type: type, name: name, container: container)
    }
    
    public func key<P, D>(type: String = String(reflecting: D.self), name: String? = nil, resolve: (P) -> D) -> Key {
        return Key(type: type, name: name, container: container)
    }
    
}
