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
final class Lock {

    private let queue: DispatchQueue
    
    init() {
        let qos: DispatchQoS
        if #available(macOS 10.10, *) {
            qos = .default
        } else {
            qos = .unspecified
        }
        let afq: DispatchQueue.AutoreleaseFrequency
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            afq = .workItem
        } else {
            afq = .inherit
        }
        queue = DispatchQueue(label: "com.prosumma.Guise.lock", qos: qos, attributes: .concurrent, autoreleaseFrequency: afq, target: nil)
    }
    
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
