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

enum Container {
    case people
    case dogs
}

struct Human {
    let name: String
}

struct Dog {
    let name: String
}

struct HumanMetadata {
    let coolness: Int
}

class GuiseTests: XCTestCase {
    
    override func tearDown() {
        Guise.clear()
        super.tearDown()
    }
    
    func testKeyEquality() {
        let key1 = Key(type: Int.self, name: "three", container: Name.default)
        let key2 = Key(type: Int.self, name: "three", container: Name.default)
        let key3 = Key(type: Int.self, name: Name.default, container: Name.default)
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testRegistrationAndResolution() {
        let _ = Guise.register{ Human(name: "Bob") }
        guard let human = Guise.resolve() as Human? else {
            XCTFail("Registration failed.")
            return
        }
        XCTAssertEqual(human.name, "Bob", "Registration failed.")
    }
    
    func testFilteringAndMetadata() {
        let names = ["Huayna Capac": 7, "Huáscar": 1, "Atahualpa": 9]
        for (name, coolness) in names {
            let _ = Guise.register(instance: Human(name: name), name: name, container: Container.people, metadata: HumanMetadata(coolness: coolness))
        }
        XCTAssertEqual(3, Guise.filter(container: Container.people).count)
        let _ = Guise.register(instance: Human(name: "Augustus"), name: "Augustus", container: Container.people, metadata: 77)
        let metafilter: Metafilter<HumanMetadata> = { $0.coolness > 1 }
        // Only two humans in Container.people have HumanMetadata with coolness > 1.
        // Augustus does not have HumanMetadata. He has Int metadata, so he is simply skipped.
        XCTAssertEqual(2, Guise.filter(container: Container.people, metafilter: metafilter).count)
    }
    
    func testRegistrationsWithEqualKeysOverwrite() {
        let fidoKey = Guise.register(container: Container.dogs) { Dog(name: "Fido") }
        // This registration should overwrite Fido's.
        let brutusKey = Guise.register(container: Container.dogs) { Dog(name: "Brutus") }
        // These two keys are equal because they register the same type in the same container.
        XCTAssertEqual(fidoKey, brutusKey)
        // We should only have 1 dog in the container…
        XCTAssertEqual(1, Guise.filter(container: Container.dogs).count)
        // and that dog should be Brutus, not Fido. Last one wins.
        let brutus = Guise.resolve(container: Container.dogs)! as Dog
        XCTAssertEqual(brutus.name, "Brutus")
    }
    
    func testResolutionWithParameter() {
        let _ = Guise.register(container: Container.dogs) { (name: String) in Dog(name: name) }
        let dog = Guise.resolve(container: Container.dogs, parameter: "Brutus")! as Dog
        XCTAssertEqual(dog.name, "Brutus")
    }
    
    func testCaching() {
        let _ = Guise.register(cached: true) { Controller() as Controlling }
        let controller1 = Guise.resolve()! as Controlling
        let controller2 = Guise.resolve()! as Controlling
        XCTAssert(controller1 === controller2)
    }
}
