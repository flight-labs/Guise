//
//  Dependency.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

class Dependency {
    private let cacheQueue: DispatchQueue
    
    /** Default lifecycle for the dependency. */
    let cached: Bool
    /** Registered block. */
    private let resolution: (Any) -> Any
    /** Cached instance, if any. */
    private var instance: Any?
    /** Metadata */
    let metadata: Any
    
    init<P, T>(metadata: Any, cached: Bool, resolution: @escaping Resolution<P, T>) {
        self.metadata = metadata
        self.cached = cached
        self.resolution = { param in resolution(param as! P) }
        self.cacheQueue = DispatchQueue(label: "com.prosumma.Guise.Dependency.\(String(reflecting: T.self)).\(UUID())")
    }
    
    func resolve<T>(parameter: Any, cached: Bool?) -> T {
        var result: T
        if cached ?? self.cached {
            // Recursion will cause a deadlock here. But that wouldn't be too smart, would it?
            cacheQueue.sync {
                if instance != nil { return }
                instance = resolution(parameter)
            }
            result = instance! as! T
        } else {
            result = resolution(parameter) as! T
        }
        return result
    }
}
