//
//  Lock.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

/**
 A simple non-reentrant GCD-powered lock allowing one writer and multiple readers.
 
 - warning: This lock is **not** re-entrant. Never resolve registrations or evaluate
 metafilters inside of a lock.
 */
class Lock {

    private let queue = DispatchQueue(label: "com.prosumma.Guise.lock", qos: .unspecified, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    
    func read<T>(_ block: () -> T) -> T {
        var result: T! = nil
        queue.sync {
            result = block()
        }
        return result
    }
    
    func write<T>(_ block: () -> T) -> T {
        var result: T! = nil
        queue.sync(flags: .barrier) {
            result = block()
        }
        return result
    }
    
}
