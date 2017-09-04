//
//  Unregistration.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    // MARK: Clear Everything
    
    public static func clear() {
        lock.write{ registrations = [:] }
    }
    
    // MARK: Unregister By Key(s)
    
    public static func unregister<K: Keyed>(keys: Set<K>) -> Int {
        let keys = keys.map{ AnyKey($0)! }
        return lock.write {
            let count = registrations.count
            registrations = registrations.filter{ !keys.contains($0.key) }
            return count - registrations.count
        }
    }
    
    public static func unregister<K: Keyed & Hashable>(keys: K...) -> Int {
        return unregister(keys: Set(keys))
    }
    
    // MARK: Unregister By Type, Name, & Container
    
    public static func unregister<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) -> Int {
        return unregister(keys: Key<T>(name: name, container: container))
    }
    
    public static func unregister<T, N: Hashable, C: Hashable, M>(type: T.Type, name: N, container: C, metafilter: @escaping Metafilter<M>) -> Int {
        guard let key = filter(type: type, name: name, container: container, metafilter: metafilter) else { return 0 }
        return unregister(keys: key)
    }
    
    public static func unregister<T, N: Hashable, C: Hashable, M: Equatable>(type: T.Type, name: N, container: C, metadata: M) -> Int {
        guard let key = filter(type: type, name: name, container: container, metadata: metadata) else { return 0 }
        return unregister(keys: key)
    }
    
    // MARK: Unregister By Type & Container
    
    public static func unregister<T, C: Hashable>(type: T.Type, container: C) -> Int {
        return unregister(keys: filter(type: type, container: container))
    }
    
    public static func unregister<T, C: Hashable, M>(type: T.Type, container: C, metafilter: @escaping Metafilter<M>) -> Int {
        return unregister(keys: filter(type: type, container: container, metafilter: metafilter))
    }
    
    public static func unregister<T, C: Hashable, M: Equatable>(type: T.Type, container: C, metadata: M) -> Int {
        return unregister(keys: filter(type: type, container: container, metadata: metadata))
    }
    
    // MARK: Unregister By Type
    
    public static func unregister<T>(type: T.Type) -> Int {
        return unregister(keys: filter(type: type))
    }
    
    public static func unregister<T, M>(type: T.Type, metafilter: @escaping Metafilter<M>) -> Int {
        return unregister(keys: filter(type: type, metafilter: metafilter))
    }
    
    public static func unregister<T, M: Equatable>(type: T.Type, metadata: M) -> Int {
        return unregister(keys: filter(type: type, metadata: metadata))
    }
    
    // MARK: Unregister By Container
    
    public static func unregister<C: Hashable>(container: C) -> Int {
        return unregister(keys: filter(container: container))
    }
    
    public static func unregister<C: Hashable, M>(container: C, metafilter: @escaping Metafilter<M>) -> Int {
        return unregister(keys: filter(container: container, metafilter: metafilter))
    }
    
    public static func unregister<C: Hashable, M: Equatable>(container: C, metadata: M) -> Int {
        return unregister(keys: filter(container: container, metadata: metadata))
    }
}
