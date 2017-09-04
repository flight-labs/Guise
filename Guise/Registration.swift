//
//  Registration.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    /**
     Register the `resolution` block.
     
     - returns: The `key` that was passed in.
     
     - parameters:
     - key: The `Key<T>` under which to register the block.
     - metadata: Arbitrary metadata associated with this registration.
     - cached: Whether or not to cache the result of the registration block.
     - resolution: The block to register with Guise.
     */
    public static func register<P, T>(key: Key<T>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        lock.write { registrations[AnyKey(key)!] = Dependency(metadata: metadata, cached: cached, resolution: resolution) }
        return key
    }
    
    /**
     Multiply register the `resolution` block.
     
     - returns: The passed-in `keys`.
     
     - parameters:
     - keys: The keys under which to register the block.
     - metadata: Arbitrary metadata associated with this registration.
     - cached: Whether or not to cache the result of the registration block.
     - resolution: The block to register with Guise.
     */
    public static func register<P, T>(keys: Set<Key<T>>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Set<Key<T>> {
        return lock.write {
            for key in keys {
                registrations[AnyKey(key)!] = Dependency(metadata: metadata, cached: cached, resolution: resolution)
            }
            return keys
        }
    }
    
    /**
     Register the `resolution` block.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
     - name: The name under which to register the block.
     - container: The container in which to register the block.
     - metadata: Arbitrary metadata associated with this registration.
     - cached: Whether or not to cache the result of the registration block after first use.
     - resolution: The block to register with Guise.
     */
    public static func register<P, T, N: Hashable, C: Hashable>(name: N, container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
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
    public static func register<P, T, N: Hashable>(name: N, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: Name.default), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register the `resolution` block.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
     - container: The container in which to register the block.
     - metadata: Arbitrary metadata associated with this registration.
     - cached: Whether or not to cache the result of the registration block.
     - resolution: The block to register with Guise.
     
     - note: The registration is made with the default name, `Name.default`.
     */
    public static func register<P, T, C: Hashable>(container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: Name.default, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    /**
     Register the `resolution` block.
     
     - returns: The unique `Key<T>` for this registration.
     
     - parameters:
     - metadata: Arbitrary metadata associated with this registration.
     - cached: Whether or not to cache the result of the registration block.
     - resolution: The block to register with Guise.
     
     - note: The registration is made in the default container, `Name.default` and under the default name, `Name.default`.
     */
    public static func register<P, T>(metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
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
    public static func register<T, N: Hashable, C: Hashable>(instance: T, name: N, container: C, metadata: Any = ()) -> Key<T> {
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
    public static func register<T, N: Hashable>(instance: T, name: N, metadata: Any = ()) -> Key<T> {
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
    public static func register<T, C: Hashable>(instance: T, container: C, metadata: Any = ()) -> Key<T> {
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
    public static func register<T>(instance: T, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: Name.default, container: Name.default), metadata: metadata, cached: true) { instance }
    }
    
}
