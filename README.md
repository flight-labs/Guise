<h1 style='text-align: center'>Guise</h1>

<!-- [![Build Status](https://travis-ci.org/Prosumma/Guise.svg)](https://travis-ci.org/Prosumma/Guise) -->
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/Guise.svg)](https://cocoapods.org)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Language](https://img.shields.io/badge/Swift-3.0-orange.svg)](http://swift.org)
![Platforms](https://img.shields.io/cocoapods/p/Guise.svg)

Guise is an elegant, flexible, type-safe dependency resolution framework for Swift.

- [x] Flexible dependency resolution, with optional caching
- [x] Elegant, straightforward registration
- [x] Thread-safe
- [x] Simplifies unit testing
- [x] Support for containers, named dependencies, and arbitrary types
- [x] Pass arbitrary state when resolving
- [x] Support for arbitrary metadata
- [x] Swift 3
- [x] Support for iOS 9+, macOS 10.11+, watchOS 2+, tvOS 9+

### Changes From Version 2.0

Guise 3.0 is not backwards-compatible with any previous version. The principle changes are these:

1. Containers have been eliminated as a separate type and are now just another `Hashable` parameter to the registration and resolution methods.
2. Caching has been simplified back to the state of affairs that existed in version 1.0. Instead of the complex lifecycles supported by version 2.0, there is only cached and not cached.
3. Names and containers can now be any `Hashable` type.
4. A set of `filter` overloads have been added which return arrays of keys. These can be used for resolving or unregistering _en masse_.
5. Arbitrary metadata can be passed during registration. This metadata can then be queried using the `filter` methods.
6. The signatures of the `register` and `resolve` overloads have been updated as needed.

### Usage

Before a dependency can be resolved, it must first be registered. Guise does not register dependencies directly. Instead, it registers blocks of type `(P) -> T`, where `P` is a parameter that can be supplied at resolution and `T` is the type of the actual dependency we wish to register. (Thanks to Swift's excellent type system, `P` can be `()`, i.e., `Void`, i.e., no parameter at all. This is the most common case.)

```swift
Guise.register{ AccountService() }
```

This registers the supplied block under the `AccountService` type, so if we ask Guise for the `AccountService`, this block will be called and its result returned:

```swift
let accountService = Guise.resolve()! as AccountService
```

#### Abstraction

Dependency resolution is most useful when it allows abstraction. This way different implementations can be swapped out as needed, whether at runtime or compile time.

```swift
#if TEST
let accountService = Guise.register{ MockAccountService() as AccountServicing }
#else
let accountService = Guise.register{ AccountService() as AccountServicing }
#endif
```

The return type of our registration block `(P) -> T` is now the `AccountServicing` protocol, which both `AccountService` and `MockAccountService` implement. When resolving, we must specify this exact type:

```swift
let accountService = Guise.resolve()! as AccountServicing
```

#### Named Registrations

Registrations are recorded based on the type returned by the registration block.

```swift
Guise.register{ AccountService() as AccountServicing }
Guise.register{ MockAccountService() as AccountServicing }
```

In this case, the second registration silently overwrites the first one. So how can two `AccountServicing` registrations be made?

```swift
Guise.register(name: "real") { AccountService() as AccountServicing }
Guise.registration(name: "mock") { MockAccountService() as AccountServicing }
```

We can then resolve the one we want quite easily.

```swift
let accountService = Guise.resolve(name: "real")! as AccountServicing
```
#### Parameters

It is sometimes useful to pass a parameter when resolving, because the initializer of the registered type requires it.

```swift
Guise.register{ (size: Int) in Shoe(size) }
```

Resolution is straightforward:

```swift
let shoe = Guise.resolve(parameter: 9)! as Shoe
```

If `parameter` is not compatible with the type specified at registration, an unrecoverable runtime exception will occur.

But what if we need more than one parameter? This can be solved using any of the various structured types offered by Guise: tuples, arrays, dictionaries, structs, classes, and so on.

```swift
typealias AccountServiceParams = (url: String, foo: Int, bar: Float)
Guise.register{ (params: AccountServiceParams) in AccountService(url: params.url, foo: params.foo, bar: params.bar) as AccountServicing }
// Later
let accountService = Guise.resolve(parameter: (url: url, foo: 17, bar: 3.9))! as AccountServicing
```

#### Caching

By default, Guise does not cache. This means that the registration block is called every time 
