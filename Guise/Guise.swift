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
    
    func resolve<T>(parameter: Any, cached: Bool?) -> T {
        var result: T
        if cached ?? self.cached {
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
    
    private static func register<P, T>(key: Key, cached: Bool = false, registration: @escaping Registration<P, T>) -> Key {
        lock.write { registrations[key] = Dependency(cached: cached, registration: registration) }
        return key
    }
    
    /**
     Register the `registration` block with the type `T` in the given `name` and `container`.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - name: The name under which to register the block.
        - container: The container in which to register the block.
        - cached: Whether or not to cache the result of the registration block.
        - registration: The block to register with Guise.
     
     ## Keys
     
     The combination of the type `T`, the `name` and the `container` creates the unique `Key` returned from this
     method. Any subsequent registration which would produce the same `Key` overwrites the previous one.
     
     The `name` and `container` parameters can be any `Hashable` type, such as `String`, `Int`, enumeration types, etc.
     
     ## Parameters
     
     The registration block can contain zero or one parameters. (Actually, the lack of a parameter is the empty tuple, `()`.)
     For example:
     
     ```
     // Registration:
     Guise.register(name: "name", container: "container") {
        TakesNoParams()
     }
     Guise.register(name: "name", container: "container") {
        (x: Int) in TakesAnInt(x: x)
     }
     
     // Resolution:
     let tnp: TakesNoParams = Guise.resolve(name: "name", container: "container")!
     let tai: TakesAnInt = Guise.resolve(name: "name", container: "container", parameter: 3)!
     ```
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
    
    /**
     Register the given instance with the specified name and in the default container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
        - instance: The instance to register.
        - name: The name under which to register the block.
    */
    public static func register<T, N: Hashable>(instance: T, name: N) -> Key {
        return register(key: Key(type: T.self, name: name, container: Name.default), cached: true) { instance }
    }
    
    /**
     Register the given instance with the default name and in the specified container.
     
     - returns: The unique `Key` for this registration.
     
     - parameters:
         - instance: The instance to register.
         - container: The container in which to register the block.
    */
    public static func register<T, C: Hashable>(instance: T, container: C) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: container), cached: true) { instance }
    }
    
    /**
     Register the given instance with the default name and in the default container.
     
     - returns: The unique `Key` for this registration.
     - parameter instance: The instance to register.
     
     - note: The `ignored` parameter is used to disambiguate an overload. Otherwise, the compiler can't figure out
     whether Guise is registering an instance or a block.
    */
    public static func register<T>(instance: T, ignored: Int = 0) -> Key {
        return register(key: Key(type: T.self, name: Name.default, container: Name.default), cached: true) { instance }
    }
    
    /**
     Resolve a dependency registered with the given key.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
        - key: The key to resolve.
        - parameter: A parameter to pass to the resolution block.
        - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public static func resolve<T>(key: Key, parameter: Any = (), cached: Bool? = nil) -> T? {
        guard let dependency = lock.read({ registrations[key] }) else { return nil }
        return dependency.resolve(parameter: parameter, cached: cached)
    }
    
    /**
     Resolve multiple registrations at the same time.
     
     - returns: An array of the resolved dependencies.
     
     - parameters:
        - keys: The keys to resolve.
        - parameter: A parameter to pass to the resolution block.
        - cached: Whether to use the cached value or to call the resolution block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
     
     Use the `filter` overloads to conveniently get a list of keys. For example,
     
     ```swift
     // Get the keys for all plugins
     let keys = Guise.filter(type: Plugin.self)
     // Resolve the keys
     let plugins: [Plugin] = Guise.resolve(keys: keys)
     ```
    */
    public static func resolve<T, K: Sequence>(keys: K, parameter: Any = (), cached: Bool? = nil) -> [T] where K.Iterator.Element == Key {
        let dependencies = lock.read {
            registrations.filter { keys.contains($0.key) }.map{ $0.value }
        }
        return dependencies.map { $0.resolve(parameter: parameter, cached: cached) }
    }
    
    /**
     Resolve a dependency registered with the given key.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - key: The key to resolve.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public static func resolve<T, N: Hashable, C: Hashable>(name: N, container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: container), parameter: parameter, cached: cached)
    }
    
    /**
     Resolve a dependency registered with the given type `T` and `name`.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - name: The name under which the block was registered.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public static func resolve<T, N: Hashable>(name: N, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: name, container: Name.default), parameter: parameter, cached: cached)
    }

    /**
     Resolve a dependency registered with the given type `T` in the given `container`.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - container: The key to resolve.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public static func resolve<T, C: Hashable>(container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: container), parameter: parameter, cached: cached)
    }

    /**
     Resolve a registered dependency.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public static func resolve<T>(parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(type: T.self, name: Name.default, container: Name.default), parameter: parameter, cached: cached)
    }
    
    private static func filter(type: String?, name: AnyHashable?, container: AnyHashable?) -> [Key] {
        return lock.read {
            var keys = [Key]()
            for key in registrations.keys {
                var append = true
                if let type = type, type != key.type { append = false }
                if let name = name, name != key.name { append = false }
                if let container = container, container != key.container { append = false }
                if append { keys.append(key) }
            }
            return keys
        }
    }
    
    public static func filter<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) -> [Key] {
        return filter(type: String(reflecting: type), name: name, container: container)
    }
    
    public static func filter<T, N: Hashable>(type: T.Type, name: N) -> [Key] {
        return filter(type: String(reflecting: type), name: name, container: nil)
    }
    
    public static func filter<T, C: Hashable>(type: T.Type, container: C) -> [Key] {
        return filter(type: String(reflecting: type), name: nil, container: container)
    }
    
    public static func filter<N: Hashable, C: Hashable>(name: N, container: C) -> [Key] {
        return filter(type: nil, name: name, container: container)
    }
    
    public static func filter<N: Hashable>(name: N) -> [Key] {
        return filter(type: nil, name: name, container: nil)
    }
    
    public static func filter<C: Hashable>(container: C) -> [Key] {
        return filter(type: nil, name: nil, container: container)
    }

    public static var keys: [Key] {
        return lock.read { Array(registrations.keys) }
    }
    
    public static func unregister(key: Key) {
        unregister(keys: [key])
    }
    
    public static func unregister<K: Sequence>(keys: K) where K.Iterator.Element == Key {
        lock.write {
            registrations = registrations.filter{ keys.contains($0.key) }.dictionary { $0 }
        }
    }
    
    public static func unregister() {
        unregister(keys: keys)
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
