//
//  Key.swift
//  Guise
//
//  Created by Gregory Higley on 9/3/17.
//  Copyright © 2017 Gregory Higley. All rights reserved.
//

import Foundation

public protocol Keyed {
    var type: String { get }
    var name: AnyHashable { get }
    var container: AnyHashable { get }
    init?(_ key: Keyed)
}

public func ==<K: Keyed & Hashable>(lhs: K, rhs: K) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.type != rhs.type { return false }
    if lhs.name != rhs.name { return false }
    if lhs.container != rhs.container { return false }
    return true
}

public struct AnyKey: Keyed, Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    public let hashValue: Int
    
    private init(type: String, name: AnyHashable, container: AnyHashable) {
        self.type = type
        self.name = name
        self.container = container
        self.hashValue = hash(self.type, self.name, self.container)
    }
    
    public init?(_ key: Keyed) {
        self.init(type: key.type, name: key.name, container: key.container)
    }
    
    public init<T>(type: T.Type, name: AnyHashable = Guise.Name.default, container: AnyHashable = Guise.Container.default) {
        self.init(type: String(reflecting: type), name: name, container: container)
    }
}

public struct Key<T>: Keyed, Hashable {
    public let type: String
    public let name: AnyHashable
    public let container: AnyHashable
    public let hashValue: Int

    /**
     - note: The `type` parameter is ignored. It exists simply to disambiguate an overload.
     Just pass `nil`.
     */
    private init(type: String?, name: AnyHashable, container: AnyHashable) {
        self.type = String(reflecting: T.self)
        self.name = name
        self.container = container
        self.hashValue = hash(self.type, self.name, self.container)
    }
    
    public init?(_ key: Keyed) {
        if key.type != String(reflecting: T.self) { return nil }
        self.init(type: nil, name: key.name, container: key.container)
    }

    public init(name: AnyHashable = Guise.Name.default, container: AnyHashable = Guise.Container.default) {
        self.init(type: nil, name: name, container: container)
    }
}
