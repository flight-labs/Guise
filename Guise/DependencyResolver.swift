//
//  DependencyResolver.swift
//
//  Created by Gregory Higley on 2/15/16.
//  Copyright © 2016 Revolucent LLC.
//

import Foundation

/**
 A simple, elegant, flexible dependency resolver.
 
 Registration uses a `type` and an optional `name`. The combination
 of `type` and `name` must be unique. Registering the same `type`
 and `name` **overwrites** the previous registration.
 */
public struct DependencyResolver {
    
    private struct Key: Hashable {
        let type: String
        let name: String?
        
        init(type: String, name: String? = nil) {
            self.type = type
            self.name = name
            // djb2 hash algorithm: http://www.cse.yorku.ca/~oz/hash.html
            // &+ operator handles Int overflow
            var hash = 5381
            hash = ((hash << 5) &+ hash) &+ type.hashValue
            if let name = name {
                hash = ((hash << 5) &+ hash) &+ name.hashValue
            }
            hashValue = hash
        }
        
        let hashValue: Int
    }
    
    private class Dependency {
        private let create: Any -> Any
        private let cached: Bool
        private var instance: Any?
        
        init<P, D>(cached: Bool, create: P -> D) {
            self.cached = cached
            self.create = { param in create(param as! P) }
        }
        
        func resolve<P, D>(parameters: P, cached: Bool) -> D {
            var result: D
            if cached && self.cached {
                if instance == nil {
                    instance = create(parameters)
                }
                result = instance! as! D
            } else {
                result = create(parameters) as! D
            }
            return result
        }
    }
    
    private static var dependencies = [Key: Dependency]()
    
    private init() {}
    
    /**
     Registers `create` with the DependencyResolver.
     
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter cached: Whether or not the instance is lazily created and then cached.
     - parameter create: The lambda to register with the DependencyResolver.
     */
    public static func register<P, D>(type type: String = String(reflecting: D.self), name: String? = nil, cached: Bool = false, create: P -> D) {
        let key = Key(type: type, name: name)
        dependencies[key] = Dependency(cached: cached, create: create)
    }
    
    /**
     Registers an existing instance with the DependencyResolver.
     
     - note: This effectively creates a singleton. If you want your singleton created lazily,
     register it with a lambda and set `cached` to true.
     
     - parameter instance: The instance to register.
     - parameter type: Usually the type of `D`, but can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     */
    public static func register<D>(instance: D, type: String = String(reflecting: D.self), name: String? = nil) {
        register(type: type, name: name, cached: true) { instance }
    }
    
    /**
     Resolves an instance of `D` in the DependencyResolver.
     
     - parameter parameters: The parameters to pass to the registered lambda.
     - parameter type: Usually the type of `D`, can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter cached: Prefer a cached value if available.
     
     - returns: The result of the registered lambda, or nil if not registered.
     
     - note: The value of `cached` is meaningful only if parallelled by a previous
     registration where `cached` was set to `true`. Otherwise it has no effect.
     */
    public static func resolve<P, D>(parameters: P, type: String = String(reflecting: D.self), name: String? = nil, cached: Bool = true) -> D? {
        let key = Key(type: type, name: name)
        guard let dependency = dependencies[key] else { return nil }
        return (dependency.resolve(parameters, cached: cached) as D)
    }
    
    /**
     Resolves an instance of `D` in the DependencyResolver.
     
     - parameter parameters: The parameters to pass to the registered lambda.
     - parameter type: Usually the type of `D`, can be any string.
     - parameter name: An optional name to disambiguate similar `type`s.
     - parameter cached: Prefer a cached value if available.
     
     - returns: The result of the registered lambda, or nil if not registered.
     
     - note: The value of `cached` is meaningful only if parallelled by a previous
     registration where `cached` was set to `true`. Otherwise it has no effect.
     */
    public static func resolve<D>(type type: String = String(reflecting: D.self), name: String? = nil, cached: Bool = true) -> D? {
        return resolve((), type: type, name: name, cached: cached)
    }
    
}

private func ==(lhs: DependencyResolver.Key, rhs: DependencyResolver.Key) -> Bool {
    if lhs.hashValue != rhs.hashValue { return false }
    if lhs.type != rhs.type { return false }
    if lhs.name != rhs.name { return false }
    return true
}