//
//  Registration.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    // MARK: Block Registration By Key
    
    public static func register<P, T>(key: Key<T>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        lock.write { registrations[AnyKey(key)!] = Dependency(metadata: metadata, cached: cached, resolution: resolution) }
        return key
    }
    
    public static func register<P, T>(keys: Set<Key<T>>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Set<Key<T>> {
        return lock.write {
            for key in keys {
                registrations[AnyKey(key)!] = Dependency(metadata: metadata, cached: cached, resolution: resolution)
            }
            return keys
        }
    }
    
    // MARK: Block Registration By Type, Name, And/Or Container
    
    public static func register<P, T, N: Hashable, C: Hashable>(name: N, container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    public static func register<P, T, N: Hashable>(name: N, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: Container.default), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    public static func register<P, T, C: Hashable>(container: C, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: Name.default, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    public static func register<P, T>(metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: Name.default, container: Container.default), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    // MARK: Instance Registration By Name And/Or Container
    
    public static func register<T, N: Hashable, C: Hashable>(instance: T, name: N, container: C, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: true) { instance }
    }
    
    public static func register<T, N: Hashable>(instance: T, name: N, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: name, container: Container.default), metadata: metadata, cached: true) { instance }
    }
    
    public static func register<T, C: Hashable>(instance: T, container: C, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: Name.default, container: container), metadata: metadata, cached: true) { instance }
    }
    
    public static func register<T>(instance: T, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: Name.default, container: Container.default), metadata: metadata, cached: true) { instance }
    }
    
}
