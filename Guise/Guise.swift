//
//  Guise.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

public struct Guise {
    public enum Name {
        case `default`
    }
    
    public enum Container {
        case `default`
    }
    
    private init() {}
    
    static var lock = Lock()
    static var registrations = [AnyKey: Dependency]()
}
