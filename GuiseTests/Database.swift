//
//  Database.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import Foundation

protocol Database: class {
    func saveItems(_ items: [Item])
    func retrieveItems() -> [Item]
}

class MemoryCache: Database {
    fileprivate var items = [Item]()
    
    func saveItems(_ items: [Item]) {
        self.items = items
    }
    
    func retrieveItems() -> [Item] {
        return items
    }
}
