//
//  Controller.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import Foundation
import Guise

protocol Controlling: class {
    func getItems()
}

class Controller: Controlling {
    func getItems() {
        let server = Locator.current.resolve()! as Serving
        server.fetch { response in
            if case .success(let items) = response {
                let database = Locator.current.resolve()! as Database
                database.saveItems(items)
            }
        }
    }
}
