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
    case Success([Item])
    case Error(ErrorType?)
}

protocol Serving {
    func fetch(callback: Response -> Void)
}

struct Server: Serving {
    func fetch(callback: Response -> Void) {
        let mainBundle = Guise.resolve(name: "main")! as NSBundle
        let path = mainBundle.pathForResource("Data", ofType: "json")!
        
        var response = Response.Error(nil)
        defer { callback(response) }
        
        do {
            guard let data = NSData(contentsOfFile: path) else { return }
            
            let array = try NSJSONSerialization.JSONObjectWithData(data, options: []) as! [[String: String]]
            let items = array.map { Item(value: $0["value"]!) }
            response = .Success(items)
        } catch let e {
            response = .Error(e)
        }
    }
}