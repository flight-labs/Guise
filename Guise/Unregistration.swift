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
    
    // MARK: Unregister By Type & Container
    
    public static func unregister<T, C: Hashable>(type: T.Type, container: C) -> Int {
        return unregister(keys: filter(type: type, container: container))
    }
    
    // MARK: Unregister by Container
    
    public static func unregister<C: Hashable>(container: C) -> Int {
        return unregister(keys: filter(container: container))
    }
    
    // MARK: Unregister By Type
    
    public static func unregister<T>(type: T.Type) -> Int {
        return unregister(keys: filter(type: type))
    }
    
}
