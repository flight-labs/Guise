//
//  ServerCommunicator.swift
//  Guise
//
//  Created by Gregory Higley on 3/7/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import Foundation

protocol ServerCommunicating {
    func retrieveWidgetCount() -> Int
}

struct ServerCommunicator: ServerCommunicating {
    let widgetCount: Int
    
    func retrieveWidgetCount() -> Int {
        return widgetCount
    }
}
