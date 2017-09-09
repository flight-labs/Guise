//
//  Resolve.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    public static func resolve<T>(keys: Set<Key<T>>, parameter: Any = (), cached: Bool? = nil) -> [Key<T>: T] {
        let keys = keys.map{ AnyKey($0)! }
        let filtered = lock.read{ registrations.filter{ keys.contains($0.key) } }
        return filtered.map{ (key: Key($0.key)!, value: $0.value.resolve(parameter: parameter, cached: cached)) }.dictionary()
    }
    
    public static func resolve<T>(keys: Set<Key<T>>, parameter: Any = (), cached: Bool? = nil) -> [T] {
        return Array(resolve(keys: keys, parameter: parameter, cached: cached).values)
    }
    
    public static func resolve<T>(keys: Key<T>...) -> [Key<T>: T] {
        return resolve(keys: Set(keys))
    }
    
    public static func resolve<T>(keys: Key<T>...) -> [T] {
        return resolve(keys: Set(keys))
    }
    
    public static func resolve<T>(key: Key<T>, parameter: Any = (), cached: Bool? = nil) -> T? {
        let key = AnyKey(key)!
        guard let registration = lock.read({ registrations[key] }) else { return nil }
        return registration.resolve(parameter: parameter, cached: cached)
    }
    
    private static func resolve<T>(name: AnyHashable, container: AnyHashable, parameter: Any, cached: Bool?, metathunk: Metathunk?) -> T? {
        let key = AnyKey(type: T.self, name: name, container: container)
        guard let registration = lock.read({ registrations[key] }) else { return nil }
        if let metathunk = metathunk, !metathunk(registration.metadata) { return nil }
        return registration.resolve(parameter: parameter, cached: cached)
    }
    
    public static func resolve<T>(type: T.Type = T.self, name: AnyHashable = Name.default, container: AnyHashable = Container.default, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(name: name, container: container, parameter: parameter, cached: cached, metathunk: nil)
    }
    
    public static func resolve<T, M>(type: T.Type = T.self, name: AnyHashable = Name.default, container: AnyHashable = Container.default, parameter: Any = (), cached: Bool? = nil, metafilter: @escaping Metafilter<M>) -> T? {
        return resolve(name: name, container: container, parameter: parameter, cached: cached, metathunk: metathunk(metafilter))
    }
    
    public static func resolve<T, M: Equatable>(type: T.Type = T.self, name: AnyHashable = Name.default, container: AnyHashable = Container.default, metadata: M, parameter: Any = (), cached: Bool? = nil) -> T? {
        return resolve(name: name, container: container, parameter: parameter, cached: cached) { $0 == metadata }
    }
}

