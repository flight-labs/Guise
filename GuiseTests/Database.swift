//
//  Database.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import Foundation

protocol Database: class {
    func saveItems(items: [Item])
    func retrieveItems() -> [Item]
}

class MemoryCache: Database {
    private var items = [Item]()
    
    func saveItems(items: [Item]) {
        self.items = items
    }
    
    func retrieveItems() -> [Item] {
        return items
    }
}