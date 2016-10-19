//
//  Server.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import Foundation
import Guise

enum Response {
    case success([Item])
    case error(Error?)
}

protocol Serving {
    func fetch(_ callback: (Response) -> Void)
}

struct Server: Serving {
    func fetch(_ callback: (Response) -> Void) {
        let mainBundle = Guise.resolve(name: "main")! as Bundle
        let path = mainBundle.path(forResource: "Data", ofType: "json")!
        
        var response = Response.error(nil)
        defer { callback(response) }
        
        do {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
            
            let array = try JSONSerialization.jsonObject(with: data, options: []) as! [[String: String]]
            let items = array.map { Item(value: $0["value"]!) }
            response = .success(items)
        } catch let e {
            response = .error(e)
        }
    }
}
