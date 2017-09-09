//
//  Register.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    // MARK: Block Registration By Key
    
    public static func register<P, T>(keys: Set<Key<T>>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Set<Key<T>> {
        return lock.write {
            for key in keys {
                registrations[AnyKey(key)!] = Registration(metadata: metadata, cached: cached, resolution: resolution)
            }
            return keys
        }
    }

    public static func register<P, T>(key: Key<T>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(keys: [key], metadata: metadata, cached: cached, resolution: resolution).first!
    }
    
    public static func register<T, P>(name: AnyHashable = Name.default, container: AnyHashable = Container.default, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: cached, resolution: resolution)
    }
    
    public static func register<T>(instance: T, name: AnyHashable = Name.default, container: AnyHashable = Container.default, metadata: Any = ()) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: true) { instance }
    }
    
    public static func register<T: Init>(type: T.Type, name: AnyHashable = Name.default, container: AnyHashable = Container.default, metadata: Any = (), cached: Bool = false) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: cached, resolution: T.init)
    }
    
    public static func register<T, I: Init>(type: T.Type, for implementation: I.Type, name: AnyHashable = Name.default, container: AnyHashable = Container.default, metadata: Any = (), cached: Bool = false) -> Key<T> {
        return register(key: Key(name: name, container: container), metadata: metadata, cached: cached) { I() as! T }
    }

}
