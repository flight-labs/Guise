//
//  Keys.swift
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
    
    public init<T, N: Hashable, C: Hashable>(type: T.Type, name: N, container: C) {
        self.init(type: String(reflecting: T.self), name: name, container: container)
    }
    
    public init<T, N: Hashable>(type: T.Type, name: N) {
        self.init(type: String(reflecting: T.self), name: name, container: Guise.Container.default)
    }
    
    public init<T, C: Hashable>(type: T.Type, container: C) {
        self.init(type: String(reflecting: T.self), name: Guise.Name.default, container: container)
    }
    
    public init<T>(type: T.Type) {
        self.init(type: String(reflecting: T.self), name: Guise.Name.default, container: Guise.Container.default)
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
    
    public init<N: Hashable, C: Hashable>(name: N, container: C) {
        self.init(type: nil, name: name, container: container)
    }
    
    public init<N: Hashable>(name: N) {
        self.init(name: name, container: Guise.Container.default)
    }
    
    public init<C: Hashable>(container: C) {
        self.init(name: Guise.Name.default, container: container)
    }
    
    public init() {
        self.init(name: Guise.Name.default, container: Guise.Container.default)
    }
}
