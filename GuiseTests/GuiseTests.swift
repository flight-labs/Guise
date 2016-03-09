//
//  GuiseTests.swift
//  GuiseTests
//
//  Created by Gregory Higley on 3/7/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import XCTest
@testable import Guise

class GuiseTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        Guise.register{ ServerCommunicator(widgetCount: 3) as ServerCommunicating }
        Guise.register(name: "sc2") { () -> ServerCommunicating in
            let eight = Guise.resolve(name: "8")! as Int
            return ServerCommunicator(widgetCount: eight)
        }
        Guise.register(name: "sc3") { (count: Int) in ServerCommunicator(widgetCount: count) as ServerCommunicating }
        Guise.register(8, name: "8") // Any type can be registered
    }
    
    func testResolveServerCommunicator() {
        let serverCommunicator = Guise.resolve()! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), 3)
    }
    
    func testResolveNamedServerCommunicator() {
        let serverCommunicator = Guise.resolve(name: "sc2")! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), 8)
    }
    
    func testResolveParameterizedNamedServerCommunicator() {
        let count = 9
        let serverCommunicator = Guise.resolve(count, name: "sc3")! as ServerCommunicating
        XCTAssertEqual(serverCommunicator.retrieveWidgetCount(), count)
    }
    
    func testResolveInt() {
        let eight = Guise.resolve(name: "8")! as Int
        XCTAssertEqual(eight, 8)
    }
}
