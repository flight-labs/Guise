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

/**
 Generates a hash value for one or more hashable values.
 */
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

/**
 A simple non-reentrant lock allowing one writer and multiple readers.
 */
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
 The protocol shared by `Key<T>` and `AnyKey`.
 */
public protocol Keyed {
    var type: String { get }
    var name: AnyHashable { get }
    var container: AnyHashable { get }
}

/**
 A type-erasing unique key under which to register a block in Guise.
 
 This type is used primarily when keys must be stored heterogeneously,
 e.g., in `Set<AnyKey>` returned from a `filter` overload.
*/
public struct AnyKey: Keyed, Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    public let hashValue: Int
    
    public init(_ key: Keyed) {
        self.type = key.type
        self.name = key.name
        self.container = key.container
        self.hashValue = Guise.hash(self.type, self.name, self.container)
    }
    
    public init<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) {
        self.type = String(reflecting: T.self)
        self.name = name
        self.container = container
        self.hashValue = Guise.hash(self.type, self.name, self.container)
    }
    
    public init<T, N: Hashable>(type: T.Type, name: N) {
        self.init(type: type, name: name, container: Name.default)
    }
    
    public init<T, C: Hashable>(type: T.Type, container: C) {
        self.init(type: type, name: Name.default, container: container)
    }
    
    public init<T>(type: T.Type) {
        self.init(type: type, name: Name.default, container: Name.default)
    }
}

extension Sequence where Iterator.Element: Keyed {
    /**
     Returns a set up of typed `Key<T>`.
     
     Any of the underlying keys whose type is not `T` 
     will simply be omitted, so this is also a way
     to filter a sequence of keys by type.
    */
    public func typedKeys<T>() -> Set<Key<T>> {
        return Set<Key<T>>(compactMap{ Key($0) })
    }
    
    /**
     Returns a set of untyped `AnyKey`.
     
     This is a convenient way to turn a set of typed
     keys into a set of untyped keys.
    */
    public func untypedKeys() -> Set<AnyKey> {
        return Set(map{ AnyKey($0) })
    }
}

public typealias GuiseKey<T> = Key<T>

extension Dictionary where Key: Keyed {
    /**
     Returns a dictionary in which the keys hold the type `T`.
     
     Any key which does not hold `T` is simply skipped, along with
     its corresponding value, so this is also a way to filter
     a sequence of keys by type.
    */
    public func typedKeys<T>() -> Dictionary<GuiseKey<T>, Value> {
        return compactMap {
            guard let key = GuiseKey<T>($0.key) else { return nil }
            return (key: key, value: $0.value)
        }.dictionary()
    }
    
    /**
     Returns a dictionary in which the keys are `AnyKey`.
     
     This is a convenient way to turn a dictionary with typed keys
     into a dictionary with type-erased keys.
    */
    public func untypedKeys() -> Dictionary<AnyKey, Value> {
        return map{ (key: AnyKey($0.key), value: $0.value) }.dictionary()
    }
}

public func ==(lhs: AnyKey, rhs: AnyKey) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.type != rhs.type { return false }
    if lhs.name != rhs.name { return false }
    if lhs.container != rhs.container { return false }
    return true
}

/**
 A type-safe registration key.
 
 This type is used wherever type-safety is needed or
 wherever keys are requested by type.
 */
public struct Key<T>: Keyed, Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    public let hashValue: Int
    
    public init<N: Hashable, C: Hashable>(name: N, container: C) {
        self.type = String(reflecting: T.self)
        self.name = name
        self.container = container
        self.hashValue = Guise.hash(self.type, self.name, self.container)
    }
    
    public init<N: Hashable>(name: N) {
        self.init(name: name, container: Name.default)
    }
    
    public init<C: Hashable>(container: C) {
        self.init(name: Name.default, container: container)
    }
    
    public init() {
        self.init(name: Name.default, container: Name.default)
    }
    
    public init?(_ key: Keyed) {
        if key.type != String(reflecting: T.self) { return nil }
        self.type = key.type
        self.name = key.name
        self.container = key.container
        self.hashValue = Guise.hash(self.type, self.name, self.container)
    }
    
}

public func ==<T>(lhs: Key<T>, rhs: Key<T>) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.name != rhs.name { return false }
    if lhs.container != rhs.container { return false }
    return true
}

/**
 The type of a resolution block.
 
 These are what actually get registered. Guise does not register
 types or instances directly.
 */
public typealias Resolution<P, T> = (P) -> T

/**
 The type of a metadata filter.
 */
public typealias Metafilter<M> = (M) -> Bool

/**
 Used in filters.
 
 This type exists primarily to emphasize that the `metathunk` method should be applied to
 `Metafilter<M>` before the metafilter is passed to the master `filter` or `exists` method.
 */
private typealias Metathunk = Metafilter<Any>

/**
 This class creates and holds a type-erasing thunk over a registration block.
 */
private class Dependency {
    /** Default lifecycle for the dependency. */
    fileprivate let cached: Bool
    /** Registered block. */
    private let resolution: (Any) -> Any
    /** Cached instance, if any. */
    private var instance: Any?
    /** Metadata */
    fileprivate let metadata: Any
    
    init<P, T>(metadata: Any, cached: Bool, resolution: @escaping Resolution<P, T>) {
        self.metadata = metadata
        self.cached = cached
        self.resolution = { param in resolution(param as! P) }
    }
    
    func resolve<T>(parameter: Any, cached: Bool?) -> T {
        var result: T
        if cached ?? self.cached {
            if instance == nil {
                instance = resolution(parameter)
            }
            result = instance! as! T
        } else {
            result = resolution(parameter) as! T
        }
        return result
    }
}

public struct Locator {
    public static var current = ServiceLocator()
}

extension ServiceLocator {
    public func with(block: (() -> Void)) {
        let orig = Locator.current
        Locator.current = self
        defer { Locator.current = orig }

        block()
    }
}

public class ServiceLocator {
    public init() {}
    
    private var lock = Lock()
    private var registrations = [AnyKey: Dependency]()

    /**
     Register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The `key` that was passed in.
     
     - parameters:
         - key: The `Key` under which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
         - cached: Whether or not to cache the result of the registration block.
         - resolution: The block to register with Guise.
    */
    @discardableResult public func register<P, T>(key: Key<T>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        lock.write { registrations[AnyKey(key)] = Dependency(metadata: metadata, cached: cached, resolution: resolution) }
        return key
    }
    
    /**
     Multiply register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The passed-in `keys`.
     
     - parameters:
         - key: The `Key` under which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
         - cached: Whether or not to cache the result of the registration block.
         - resolution: The block to register with Guise.
    */
    @discardableResult public func register<P, T>(keys: Set<Key<T>>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Set<Key<T>> {
        return lock.write {
            for key in keys {
                registrations[AnyKey(key)] = Dependency(metadata: metadata, cached: cached, resolution: resolution)
            }
            return keys
        }
    }
    
    /**
     Register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
        - name: The name under which to register the block.
        - container: The container in which to register the block.
        - metadata: Arbitrary metadata associated with this registration.
        - cached: Whether or not to cache the result of the registration block.
        - resolution: The block to register with Guise.
    */
    @discardableResult public func register<P, T, N: Hashable, C: Hashable>(name: N, container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - name: The name under which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
         - cached: Whether or not to cache the result of the registration block.
         - resolution: The block to register with Guise.
     
     - note: The registration is made in the default container, `Name.default`.
     */
    @discardableResult public func register<P, T, N: Hashable>(name: N, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: Name.default), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - container: The container in which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
         - cached: Whether or not to cache the result of the registration block.
         - resolution: The block to register with Guise.
     
     - note: The registration is made with the default name, `Name.default`.
     */
    @discardableResult public func register<P, T, C: Hashable>(container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: Name.default, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register the `resolution` block with the result type `T` and the parameter `P`.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - metadata: Arbitrary metadata associated with this registration.
         - cached: Whether or not to cache the result of the registration block.
         - resolution: The block to register with Guise.
     
     - note: The registration is made in the default container, `Name.default` and under the default name, `Name.default`.
    */
    @discardableResult public func register<P, T>(metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: Name.default, container: Name.default), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register an instance.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
        - instance: The instance to register.
        - name: The name under which to register the block.
        - container: The container in which to register the block.
        - metadata: Arbitrary metadata associated with this registration.
    */
    @discardableResult public func register<T, N: Hashable, C: Hashable>(instance: T, name: N, container: C, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: true) { instance }
    }
    
    /**
     Register an instance.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - instance: The instance to register.
         - name: The name under which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
     
     - note: The registration is made in the default container, `Name.default`.
    */
    @discardableResult public func register<T, N: Hashable>(instance: T, name: N, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: name, container: Name.default), metadata: metadata, cached: true) { instance }
    }
    
    /**
     Register an instance.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - instance: The instance to register.
         - container: The container in which to register the block.
         - metadata: Arbitrary metadata associated with this registration.
     
     - note: The registration is made with the default name, `Name.default`.
    */
    @discardableResult public func register<T, C: Hashable>(instance: T, container: C, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: Name.default, container: container), metadata: metadata, cached: true) { instance }
    }
    
    /**
     Register an instance.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
         - instance: The instance to register.
         - metadata: Arbitrary metadata associated with this registration.
     
     - note: The registration is made with the default name, `Name.default`, and in the default container, `Name.default`.
     */
    @discardableResult public func register<T>(instance: T, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: Name.default, container: Name.default), metadata: metadata, cached: true) { instance }
    }
    
    /**
     Resolve a dependency registered with `key`.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
        - key: The key to resolve.
        - parameter: A parameter to pass to the resolution block.
        - cached: Whether to use the cached value or to call the block again.
     
     - note: Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public func resolve<T>(key: Key<T>, parameter: Any = (), cached: Bool? = nil) -> T? {
        guard let dependency = lock.read({ registrations[AnyKey(key)] }) else { return nil }
        return dependency.resolve(parameter: parameter, cached: cached)
    }
    
    /**
     Resolve multiple registrations at the same time.
     
     - returns: An array of the resolved dependencies.
     
     - parameters:
        - keys: The keys to resolve.
        - parameter: A parameter to pass to the resolution block.
        - cached: Whether to use the cached value or to call the resolution block again.
     
     - note: Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public func resolve<T>(keys: Set<Key<T>>, parameter: Any = (), cached: Bool? = nil) -> [T] {
        let dependencies: [Dependency] = lock.read {
            var dependencies = [Dependency]()
            for (key, dependency) in registrations {
                guard let key = Key<T>(key) else { continue }
                if !keys.contains(key) { continue }
                dependencies.append(dependency)
            }
            return dependencies
        }
        return dependencies.map{ $0.resolve(parameter: parameter, cached: cached) }
    }
    
    /**
     Resolve multiple registrations at the same time.
     
     - returns: A dictionary mapping each supplied `Key` to its resolved dependency of type `T`.
     
     - parameters:
         - keys: The keys to resolve.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the resolution block again.
     
;     - note: Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public func resolve<T>(keys: Set<Key<T>>, parameter: Any = (), cached: Bool? = nil) -> [Key<T>: T] {
        let dependencies: Dictionary<Key<T>, Dependency> = lock.read {
            var dependencies = Dictionary<Key<T>, Dependency>()
            for (key, dependency) in registrations {
                guard let key = Key<T>(key) else { continue }
                if !keys.contains(key) { continue }
                dependencies[key] = dependency
            }
            return dependencies
        }
        return dependencies.map{ (key: $0.key, value: $0.value.resolve(parameter: parameter, cached: cached)) }.dictionary()
    }
    
    /**
     Resolve a dependency registered with the given key.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - name: The name under which the block was registered.
         - container: The container in which the block was registered.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public func resolve<T, N: Hashable, C: Hashable>(name: N, container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(name: name, container: container), parameter: parameter, cached: cached)
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
    public func resolve<T, N: Hashable>(name: N, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(name: name, container: Name.default), parameter: parameter, cached: cached)
    }

    /**
     Resolve a dependency registered with the given type `T` in the given `container`.
     
     - returns: The resolved dependency or `nil` if it is not found.
     
     - parameters:
         - container: The container in which the block was registered.
         - parameter: A parameter to pass to the resolution block.
         - cached: Whether to use the cached value or to call the block again.
     
     Passing `nil` for the `cached` parameter causes Guise to use the value of `cached` recorded
     when the dependency was registered. In most cases, this is what you want.
    */
    public func resolve<T, C: Hashable>(container: C, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(name: Name.default, container: container), parameter: parameter, cached: cached)
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
    public func resolve<T>(parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(key: Key(name: Name.default, container: Name.default), parameter: parameter, cached: cached)
    }
    
    /**
     Provides a thunk between `Metafilter<M>` and `Metafilter<Any>`.
     
     Checks to make sure that the metadata being checked actually is of type `M`.
    */
    private func metathunk<M>(_ metafilter: @escaping Metafilter<M>) -> Metathunk {
        return {
            guard let metadata = $0 as? M else { return false }
            return metafilter(metadata)
        }
    }
    
    /**
     Most of the typed `filter` overloads end up here.
    */
    private func filter<T>(name: AnyHashable?, container: AnyHashable?, metafilter: Metathunk? = nil) -> Set<Key<T>> {
        return lock.read {
            var keys = Set<Key<T>>()
            for (key, dependency) in registrations {
                guard let key = Key<T>(key) else { continue }
                if let name = name, name != key.name { continue }
                if let container = container, container != key.container { continue }
                if let metafilter = metafilter, !metafilter(dependency.metadata) { continue }
                keys.insert(key)
            }
            return keys
        }
    }
    
    /**
     Most of the untyped `filter` overloads end up here.
    */
    private func filter(name: AnyHashable?, container: AnyHashable?, metafilter: Metathunk? = nil) -> Set<AnyKey> {
        return lock.read {
            var keys = Set<AnyKey>()
            for (key, dependency) in registrations {
                if let name = name, name != key.name { continue }
                if let container = container, container != key.container { continue }
                if let metafilter = metafilter, !metafilter(dependency.metadata) { continue }
                keys.insert(key)
            }
            return keys
        }
    }
    
    /**
     Find the given key matching the metafilter query.
     
     This method will always return either an empty set or a set with one element.
    */
    public func filter<T, M>(key: Key<T>, metafilter: @escaping Metafilter<M>) -> Set<Key<T>> {
        guard let dependency = lock.read({ registrations[AnyKey(key)] }) else { return [] }
        return metathunk(metafilter)(dependency.metadata) ? [key] : []
    }
    
    /**
     Find the given key.
    */
    public func filter<T>(key: Key<T>) -> Set<Key<T>> {
        return lock.read{ registrations[AnyKey(key)] == nil ? [] : [key] }
    }
    
    /**
     Find all keys for the given type, name, and container.
     
     Because all of type, name, and container are specified, this particular method will return either 
     an empty array or an array with a single value.
    */
    public func filter<T, N: Hashable, C: Hashable, M>(type: T.Type, name: N, container: C, metafilter: @escaping Metafilter<M>) -> Set<Key<T>> {
        let key = Key<T>(name: name, container: container)
        return filter(key: key, metafilter: metafilter)
    }
    
    /**
     Find all keys for the given type, name, and container.
     
     Because all of type, name, and container are specified, this particular method will return either
     an empty array or an array with a single value.
     */
    public func filter<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) -> Set<Key<T>> {
        let key = Key<T>(name: name, container: container)
        return filter(key: key)
    }
    
    /**
     Find all keys for the given type and name, independent of container.
    */
    public func filter<T, N: Hashable, M>(type: T.Type, name: N, metafilter: @escaping Metafilter<M>) -> Set<Key<T>> {
        return filter(name: name, container: nil, metafilter: metathunk(metafilter))
    }

    /**
     Find all keys for the given type and name, independent of container.
     */
    public func filter<T, N: Hashable>(type: T.Type, name: N) -> Set<Key<T>> {
        return filter(name: name, container: nil, metafilter: nil)
    }
    
    /**
     Find all keys for the given type and container, independent of name.
    */
    public func filter<T, C: Hashable, M>(type: T.Type, container: C, metafilter: @escaping Metafilter<M>) -> Set<Key<T>> {
        return filter(name: nil, container: container, metafilter: metathunk(metafilter))
    }
    
    /**
     Find all keys for the given name and container, independent of type.
    */
    public func filter<N: Hashable, C: Hashable, M>(name: N, container: C, metafilter: @escaping Metafilter<M>) -> Set<AnyKey> {
        return filter(name: name, container: container, metafilter: metathunk(metafilter))
    }

    /**
     Find all keys for the given name and container, independent of type.
     */
    public func filter<N: Hashable, C: Hashable>(name: N, container: C) -> Set<AnyKey> {
        return filter(name: name, container: container, metafilter: nil)
    }
    
    /**
     Find all keys for the given name, independent of the given type and container.
    */
    public func filter<N: Hashable, M>(name: N, metafilter: @escaping Metafilter<M>) -> Set<AnyKey> {
        return filter(name: name, container: nil, metafilter: metathunk(metafilter))
    }

    /**
     Find all keys for the given name, independent of the given type and container.
     */
    public func filter<N: Hashable>(name: N) -> Set<AnyKey> {
        return filter(name: name, container: nil, metafilter: nil)
    }
    
    /**
     Find all keys for the given container, independent of given type and name.
    */
    public func filter<C: Hashable, M>(container: C, metafilter: @escaping Metafilter<M>) -> Set<AnyKey> {
        return filter(name: nil, container: container, metafilter: metathunk(metafilter))
    }

    /**
     Find all keys for the given container, independent of given type and name.
     */
    public func filter<C: Hashable>(container: C) -> Set<AnyKey> {
        return filter(name: nil, container: container, metafilter: nil)
    }
    
    /**
     Find all keys for the given type, independent of name and container.
    */
    public func filter<T, M>(type: T.Type, metafilter: @escaping Metafilter<M>) -> Set<Key<T>> {
        return filter(name: nil, container: nil, metafilter: metathunk(metafilter))
    }
    
    /**
     Find all keys for the given type, independent of name and container.
     */
    public func filter<T>(type: T.Type) -> Set<Key<T>> {
        return filter(name: nil, container: nil, metafilter: nil)
    }
    
    /**
     Find all keys with registrations matching the metafilter query.
    */
    public func filter<M>(metafilter: @escaping Metafilter<M>) -> Set<AnyKey> {
        return filter(name: nil, container: nil, metafilter: metathunk(metafilter))
    }
    
    /**
     Helper method for filtering.
     */
    private func exists(type: String?, name: AnyHashable?, container: AnyHashable?, metafilter: Metathunk? = nil) -> Bool {
        return lock.read {
            for (key, dependency) in registrations {
                if let type = type, type != key.type { continue }
                if let name = name, name != key.name { continue }
                if let container = container, container != key.container { continue }
                if let metafilter = metafilter, !metafilter(dependency.metadata) { continue }
                return true
            }
            return false
        }
    }
    
    /**
     Returns true if a registration exists for `key` and matching the `metafilter` query.
    */
    public func exists<M>(key: Keyed, metafilter: @escaping Metafilter<M>) -> Bool {
        guard let dependency = lock.read({ registrations[AnyKey(key)] }) else { return false }
        return metathunk(metafilter)(dependency.metadata)
    }

    /**
     Returns true if a registration exists for the given key.
     */
    public func exists(key: Keyed) -> Bool {
        return lock.read { return registrations[AnyKey(key)] != nil }
    }
    
    /**
     Returns true if a key with the given type, name, and container exists.
    */
    public func exists<T, N: Hashable, C: Hashable, M>(type: T.Type, name: N, container: C, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(key: Key<T>(name: name, container: container), metafilter: metathunk(metafilter))
    }

    /**
     Returns true if a key with the given type, name, and container exists.
     */
    public func exists<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) -> Bool {
        return exists(key: AnyKey(type: type, name: name, container: container))
    }
    
    /**
     Returns true if any keys with the given type and name exist in any containers.
    */
    public func exists<T, N: Hashable, M>(type: T.Type, name: N, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: String(reflecting: type), name: name, container: nil, metafilter: metathunk(metafilter))
    }

    /**
     Returns true if any keys with the given type and name exist in any containers.
     */
    public func exists<T, N: Hashable>(type: T.Type, name: N) -> Bool {
        return exists(type: String(reflecting: type), name: name, container: nil, metafilter: nil)
    }
    
    /**
     Returns true if any keys with the given type exist in the given container, independent of name.
    */
    public func exists<T, C: Hashable, M>(type: T.Type, container: C, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: String(reflecting: type), name: nil, container: container, metafilter: metathunk(metafilter))
    }

    /**
     Returns true if any keys with the given type exist in the given container, independent of name.
     */
    public func exists<T, C: Hashable>(type: T.Type, container: C) -> Bool {
        return exists(type: String(reflecting: type), name: nil, container: container, metafilter: nil)
    }
    
    /**
     Returns true if any keys with the given name exist in the given container, independent of type.
    */
    public func exists<N: Hashable, C: Hashable, M>(name: N, container: C, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: nil, name: name, container: container, metafilter: metathunk(metafilter))
    }

    /**
     Returns true if any keys with the given name exist in the given container, independent of type.
     */
    public func exists<N: Hashable, C: Hashable>(name: N, container: C) -> Bool {
        return exists(type: nil, name: name, container: container, metafilter: nil)
    }
    
    /**
     Return true if any keys with the given name exist in any container, independent of type.
    */
    public func exists<N: Hashable, M>(name: N, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: nil, name: name, container: nil, metafilter: metathunk(metafilter))
    }
    
    /**
     Returns true if any registrations exist under the given name.
    */
    public func exists<N: Hashable>(name: N) -> Bool {
        return exists(type: nil, name: name, container: nil, metafilter: nil)
    }
    
    /**
     Returns true if there are any keys registered in the given container, matching the given metafilter query.
    */
    public func exists<C: Hashable, M>(container: C, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: nil, name: nil, container: container, metafilter: metathunk(metafilter))
    }

    /**
     Returns true if there are any keys registered in the given container.
     */
    public func exists<C: Hashable>(container: C) -> Bool {
        return exists(type: nil, name: nil, container: container, metafilter: nil)
    }
    
    /**
     Returns true if there are any keys registered with the given type and matching the metafilter query in any container, independent of name.
    */
    public func exists<T, M>(type: T.Type, metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: String(reflecting: type), name: nil, container: nil, metafilter: metathunk(metafilter))
    }

    /**
     Returns true if there are any keys registered with the given type in any container, independent of name.
     */
    public func exists<T>(type: T.Type) -> Bool {
        return exists(type: String(reflecting: type), name: nil, container: nil, metafilter: nil)
    }
    
    /**
     Returns true if any registrations exist matching the given metafilter, regardless of type, name, or container.
    */
    public func exists<M>(metafilter: @escaping Metafilter<M>) -> Bool {
        return exists(type: nil, name: nil, container: nil, metafilter: metathunk(metafilter))
    }
    
    /**
     All keys.
    */
    public var keys: Set<AnyKey> {
        return lock.read { Set(registrations.keys) }
    }
    
    /**
     Retrieve metadata for the dependency registered under `key`.
    */
    public func metadata<M>(for key: Keyed) -> M? {
        guard let dependency = lock.read({ registrations[AnyKey(key)] }) else { return nil }
        guard let metadata = dependency.metadata as? M else { return nil }
        return metadata
    }
    
    /**
     Retrieve metadata for multiple keys.
    */
    public func metadata<M>(for keys: Set<AnyKey>) -> [AnyKey: M] {
        return lock.read {
            var metadatas = [AnyKey: M]()
            for (key, dependency) in registrations {
                if !keys.contains(key) { continue }
                guard let metadata = dependency.metadata as? M else { continue }
                metadatas[key] = metadata
            }
            return metadatas
        }
    }

    /**
     Retrieve metadata for multiple keys.
    */
    public func metadata<T, M>(for keys: Set<Key<T>>) -> [Key<T>: M] {
        return lock.read {
            var metadatas = Dictionary<Key<T>, M>()
            for (key, dependency) in registrations {
                guard let key = Key<T>(key) else { continue }
                if !keys.contains(key) { continue }
                guard let metadata = dependency.metadata as? M else { continue }
                metadatas[key] = metadata
            }
            return metadatas
        }
    }
    
    /**
     Remove the dependencies registered under the given key(s).
    */
    public func unregister(key: AnyKey...) {
        unregister(keys: key.untypedKeys())
    }
    
    /**
     Remove the dependencies registered under the given key(s).
    */
    public func unregister<T>(key: Key<T>...) {
        unregister(keys: key.untypedKeys())
    }
    
    /**
     Remove the dependencies registered under the given keys.
    */
    public func unregister(keys: Set<AnyKey>)  {
        lock.write { registrations = registrations.filter{ !keys.contains($0.key) }.dictionary() }
    }
    
    /**
     Remove the dependencies registered under the given keys.
    */
    public func unregister<T>(keys: Set<Key<T>>) {
        unregister(keys: keys.untypedKeys())
    }
    
    /**
     Remove all dependencies. Reset Guise completely.
    */
    public func clear() {
        lock.write { registrations = [:] }
    }
}

extension Array {
    /**
     Reconstruct a dictionary after it's been reduced to an array of key-value pairs by `filter` and the like.
     
     ```
     var dictionary = [1: "ok", 2: "crazy", 99: "abnormal"]
     dictionary = dictionary.filter{ $0.value == "ok" }.dictionary()
     ```
    */
    func dictionary<K: Hashable, V>() -> [K: V] where Element == Dictionary<K, V>.Element {
        var dictionary = [K: V]()
        for element in self {
            dictionary[element.key] = element.value
        }
        return dictionary
    }
}
