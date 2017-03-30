//
//  GuiseTests.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import XCTest
@testable import Guise

enum BundleName {
    case main
}

struct Human {
    let name: String
}

class GuiseTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        
        let _ = Guise.register(instance: Bundle(for: GuiseTests.self), name: BundleName.main)
        let _ = Guise.register(cached: true) { MemoryCache() as Database }
        let _ = Guise.register { Server() as Serving }
        let _ = Guise.register(metadata: ["this": 3, 3: "this"]) { Controller() as Controlling }
        let _ = Guise.register(container: "watusi") { Controller() as Controlling }
        
        let _ = Guise.register(instance: Human(name: "Fred"), name: "Fred", metadata: ["coolness": 4])
        let _ = Guise.register(instance: Human(name: "Greg"), name: "Greg", metadata: ["coolness": 1])
        let _ = Guise.register(instance: Human(name: "Blain"), name: "Blain", metadata: ["coolness": 10])
    }
    
    func testResolveMainBundle() {
        let mainBundle = Guise.resolve(name: BundleName.main) as Bundle?
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
    
    func testClearContainer() {
        let container = "watusi"
        var controller = Guise.resolve(container: container) as Controlling?
        XCTAssertNotNil(controller)
        Guise.unregister(keys: Guise.filter(container: container))
        controller = Guise.resolve(container: container) as Controlling?
        XCTAssertNil(controller)
    }

    func testControllerServerAndDatabase() {
        let controller = Guise.resolve() as Controlling!
        XCTAssertNotNil(controller)
        controller!.getItems()
        let database = Guise.resolve() as Database!
        XCTAssertNotNil(database)
        XCTAssertEqual(database!.retrieveItems().count, 3)
    }
    
    func testMetadata() {
        let keys = Guise.filter { metadata in metadata["this"] != nil }
        XCTAssertEqual(keys.count, 1)
    }
    
    func testResolveAllHumansWithCoolnessGreaterThan1() {
        let keys = Guise.filter(type: Human.self) { metadata in ((metadata["coolness"] ?? 0) as! Int) > 1}
        let humans: [Human] = Guise.resolve(keys: keys)
        XCTAssertEqual(humans.count, 2)
    }

    func testKeyEquality() {
        let key1 = Guise.register(instance: 3, name: "three")
        let key2 = Guise.register(instance: 3, name: "three")
        let key3 = Guise.register(instance: 3)
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }    
}
