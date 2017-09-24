//
//  Register.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

/**
 A protocol that allows types to be registered directly.
 
 Under the hood, Guise _always_ registers a block. However,
 if a type uses a parameterless initializer, which is a very
 common case, it can be convenient simply to specify the type.
 
 For example, in place of `_ = Guise.register{ Foo() }`, one could
 say `_ = Guise.register(type: Foo.self)` as long as `Foo` adopts
 the `Init` protocol.
 
 In the case where the type is aliased, for example in `_ = Guise.register{ Foo() as Bar }`,
 we can say `_ = Guise.register(type: Bar.self, for: Foo.self)`.
 `Foo` must still adopt `Init`.
 */
public protocol Init {
    init()
}

extension Guise {
    
    /**
     Register a single resolution block with multiple keys.
     
     Direct use of this method will most likely be rare. However, it is the "master" registration method. All other registration
     methods ultimately call this one.
     */
    public static func register<P, T>(keys: Set<Key<T>>, metadata: Any = (), cached: Bool = false, resolution: @escaping Resolution<P, T>) -> Set<Key<T>> {
        return lock.write {
            for key in keys {
                registrations[AnyKey(key)!] = Registration(metadata: metadata, cached: cached, resolution: resolution)
            }
            return keys
        }
    }

    /**
     Register a resolution block with a key.
     
     
     */
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
