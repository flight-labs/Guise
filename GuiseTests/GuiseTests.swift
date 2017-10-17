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

protocol Animal {
    var name: String { get }
}

struct Human: Animal {
    let name: String
}

struct Dog: Animal {
    let name: String
}

struct HumanMetadata {
    let coolness: Int
}

class GuiseTests: XCTestCase {
    
    override func tearDown() {
        Locator.current.clear()
        super.tearDown()
    }
    
    func testKeyEquality() {
        let key1 = Key<Int>(name: "three", container: Name.default)
        let key2 = Key<Int>(name: "three", container: Name.default)
        let key3 = Key<Int>(name: Name.default, container: Name.default)
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testFilteringAndMetadata() {
        let names = ["Huayna Capac": 7, "Huáscar": 1, "Atahualpa": 9]
        for (name, coolness) in names {
            let _ = Locator.current.register(instance: Human(name: name), name: name, container: Container.people, metadata: HumanMetadata(coolness: coolness))
        }
        XCTAssertEqual(3, Locator.current.filter(container: Container.people).count)
        let _ = Locator.current.register(instance: Human(name: "Augustus"), name: "Augustus", container: Container.people, metadata: 77)
        var metafilter: Metafilter<HumanMetadata> = { $0.coolness > 1 }
        // Only two humans in Container.people have HumanMetadata with coolness > 1.
        // Augustus does not have HumanMetadata. He has Int metadata, so he is simply skipped.
        XCTAssertEqual(2, Locator.current.filter(container: Container.people, metafilter: metafilter).count)
        let _ = Locator.current.register(instance: Human(name: "Trump"), metadata: HumanMetadata(coolness: 0))
        // This metafilter effectively queries for all registrations using HumanMetadata,
        // regardless of the value of this Metadata.
        metafilter = { _ in true }
        // We have 4 Humans matching the metafilter query. 3 in Container.people and 1 in the default container.
        XCTAssertEqual(4, Locator.current.filter(type: Human.self, metafilter: metafilter).count)
        let _ = Locator.current.register(instance: Dog(name: "Brian Griffin"), metadata: HumanMetadata(coolness: 10))
        // After we added a dog with HumanMetadata, we query by metafilter only, ignoring type and container.
        // We have 5 matching registrations: the three Sapa Incas, Trump, and Brian Griffin.
        XCTAssertEqual(5, Locator.current.filter(metafilter: metafilter).count)
    }
    
    func testRegistrationsWithEqualKeysOverwrite() {
        let fidoKey = Locator.current.register(container: Container.dogs) { Dog(name: "Fido") }
        // This registration should overwrite Fido's.
        let brutusKey = Locator.current.register(container: Container.dogs) { Dog(name: "Brutus") }
        // These two keys are equal because they register the same type in the same container.
        XCTAssertEqual(fidoKey, brutusKey)
        // We should only have 1 dog in the container…
        XCTAssertEqual(1, Locator.current.filter(container: Container.dogs).count)
        // and that dog should be Brutus, not Fido. Last one wins.
        let brutus = Locator.current.resolve(container: Container.dogs)! as Dog
        XCTAssertEqual(brutus.name, "Brutus")
    }
    
    func testMultipleRegistrations() {
        let keys: Set<Key<Animal>> = [Key(name: "Lucy"), Key(name: "Fido")]
        let _ = Locator.current.register(keys: keys) { (name: String) in Dog(name: name) as Animal }
        var name = "Fido"
        XCTAssertNotNil(Locator.current.resolve(name: name, parameter: name) as Animal?)
        name = "Lucy"
        XCTAssertNotNil(Locator.current.resolve(name: name, parameter: name) as Animal?)
    }
    
    func testResolutionWithParameter() {
        let _ = Locator.current.register(container: Container.dogs) { (name: String) in Dog(name: name) }
        let dog = Locator.current.resolve(container: Container.dogs, parameter: "Brutus")! as Dog
        XCTAssertEqual(dog.name, "Brutus")
    }
    
    func testCaching() {
        let _ = Locator.current.register(cached: true) { Controller() as Controlling }
        let controller1 = Locator.current.resolve()! as Controlling
        let controller2 = Locator.current.resolve()! as Controlling
        // Because we asked Guise to cache this registration, we should get back the same reference every time.
        XCTAssert(controller1 === controller2)
        // Here we've asked Guise to call the registered block again, thus creating a new instance.
        let controller3 = Locator.current.resolve(cached: false)! as Controlling
        XCTAssertFalse(controller1 === controller3)
        // However, the existing cached instance is still there.
        let controller4 = Locator.current.resolve()! as Controlling
        XCTAssert(controller1 === controller4)
    }
    
    func testMultipleResolutionsWithMetafilter() {
        let names = ["Huayna Capac": 7, "Huáscar": 1, "Atahualpa": 9]
        for (name, coolness) in names {
            let _ = Locator.current.register(instance: Human(name: name), name: name, container: Container.people, metadata: HumanMetadata(coolness: coolness))
        }
        let _ = Locator.current.register(instance: Human(name: "Augustus"), name: "Augustus", container: Container.people, metadata: 77)
        let metafilter: Metafilter<HumanMetadata> = { $0.coolness > 1 }
        let keys = Locator.current.filter(type: Human.self, container: Container.people, metafilter: metafilter)
        let people = Locator.current.resolve(keys: keys) as [Human]
        XCTAssertEqual(2, people.count)
    }
    
    func testMultipleHeterogeneousResolutionsUsingProtocol() {
        let _ = Locator.current.register(instance: Human(name: "Lucy") as Animal, name: "Lucy")
        let _ = Locator.current.register(instance: Dog(name: "Fido") as Animal, name: "Fido")
        let keys = Locator.current.filter(type: Animal.self)
        let animals = Locator.current.resolve(keys: keys) as [Animal]
        XCTAssertEqual(2, animals.count)
    }
    
    func testMultipleResolutionsReturningDictionary() {
        let _ = Locator.current.register(instance: Human(name: "Lucy") as Animal, name: "Lucy", metadata: 3)
        let _ = Locator.current.register(instance: Dog(name: "Fido") as Animal, name: "Fido", metadata: 10)
        let _ = Locator.current.register(instance: 7, metadata: 4)
        let metafilter: Metafilter<Int> = { $0 >= 3 }
        let keys = Locator.current.filter(type: Animal.self, metafilter: metafilter)
        let animals = Locator.current.resolve(keys: keys) as [Key<Animal>: Animal]
        // The registration of the integer 7 above is skipped, because it is not an Animal.
        XCTAssertEqual(2, animals.count)
    }
    
    func testResolutionByKey() {
        let key = Locator.current.register(instance: Dog(name: "Lucy"))
        XCTAssertNotNil(Locator.current.resolve(key: key) as Dog?)
    }
    
    func testResolutionsWithKeysOfIncorrectTypeAreSkipped() {
        let _ = Locator.current.register(instance: Human(name: "Abraham Lincoln"), metadata: HumanMetadata(coolness: 9))
        let _ = Locator.current.register(instance: Dog(name: "Brian Griffin"), metadata: HumanMetadata(coolness: 10))
        let metafilter: Metafilter<HumanMetadata> = { $0.coolness > 5 }
        let keys = Locator.current.filter(metafilter: metafilter)
        // We get back two keys, but they resolve disparate types.
        XCTAssertEqual(2, keys.count)
        let humans = Locator.current.resolve(keys: keys.typedKeys()) as [Human]
        // Because we are resolving Humans, not Dogs, Brian Griffin is skipped.
        XCTAssertEqual(1, humans.count)
    }
}
