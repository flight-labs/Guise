//
//  Unregister.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

extension Guise {
    
    // MARK: Clear Everything
    
    public static func clear() -> Int {
        return lock.write {
            let count = registrations.count
            registrations = [:]
            return count
        }
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

    public static func unregister<T>(type: T.Type, name: AnyHashable? = nil, container: AnyHashable? = nil) -> Int {
        return unregister(keys: filter(type: type, name: name, container: container))
    }
    
    public static func unregister(name: AnyHashable? = nil, container: AnyHashable? = nil) -> Int {
        if name == nil && container == nil {
            return clear()
        } else {
            return unregister(keys: filter(name: name, container: container))
        }
    }
    
}
