//
//  GuiseTests.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import XCTest
@testable import Guise

class GuiseTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        
        let _ = Guise.register(instance: Bundle(for: GuiseTests.self), name: "main")
        let _ = Guise.register(lifecycle: .cached) { MemoryCache() as Database }
        let _ = Guise.register { Server() as Serving }
        let _ = Guise.register { Controller() as Controlling }
    }
    
    func testResolveMainBundle() {
        let mainBundle = Guise.resolve(name: "main") as Bundle?
        XCTAssertNotNil(mainBundle)
        let path = mainBundle!.path(forResource: "Data", ofType: "json")
        XCTAssertNotNil(path)
    }
    
    func testResolveServer() {
        XCTAssertNotNil(Guise.resolve() as Serving?)
    }
    
    func testResolveController() {
        XCTAssertNotNil(Guise.resolve() as Controlling?)
    }

    func testThatCachedIsCached() {
        // Note that only ref types work here. Caching structs is possible, but not terribly useful.
        let database1 = Guise.resolve() as Database?
        XCTAssertNotNil(database1)
        let database2 = Guise.resolve() as Database?
        XCTAssertNotNil(database2)
        XCTAssertTrue(database1 === database2)
    }

    func testControllerServerAndDatabase() {
        let controller = Guise.resolve() as Controlling!
        XCTAssertNotNil(controller)
        controller!.getItems()
        let database = Guise.resolve() as Database!
        XCTAssertNotNil(database)
        XCTAssertEqual(database!.retrieveItems().count, 3)
    }
}
