<h1 style='text-align: center'>Guise</h1>

<!-- [![Build Status](https://travis-ci.org/Prosumma/Guise.svg)](https://travis-ci.org/Prosumma/Guise) -->
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/Guise.svg)](https://cocoapods.org)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
![Platforms](https://img.shields.io/cocoapods/p/Guise.svg)

Guise is an elegant, flexible, type-safe dependency resolution framework for Swift.

- [x] Flexible dependency resolution, with optional caching
- [x] Elegant, straightforward registration
- [x] Simplifies unit testing
- [x] Support for containers, named dependencies, and arbitrary types
- [x] Pass arbitrary state when resolving
- [x] Swift 3
- [x] Support for iOS 9+, macOS 10.11+, watchOS 2+, tvOS 9+

### Usage

Guise supports two basic operations: registration and resolution. Registration is the act of registering a block whose return type is used as a key when resolution is needed. Resolution is the act of calling the registered block and returning its result. By using a block to register, _any_ Swift type is supported, even if we do not have access to a constructor.

```swift
Guise.register { Service() }
```

Here we register a block that constructs and returns a `Service` instance. The `Service` type is used as a key to call the block and get an instance:

```swift
let service = Guise.resolve()! as Service
```

Of course, this isn't very useful if we can just call the `Service` constructor directly. Most of the time we want to return an abstract type, such as a protocol, so that we can vary the actual implementation as needed:

```swift
Guise.register { Service() as Servicing }
// Later:
let service = Guise.resolve()! as Servicing
```

Here, `Servicing` is a protocol. Guise hides the underlying type we are actually using so that we can easily replace it—for example, in unit tests:

```swift
Guise.register { FakeService() as Servicing }
// Later:
let service = Guise.resolve()! as Servicing
```

#### Lifecycle

One common scenario is that we want to cache the result of the block and thereafter return only that result. This is supported with the `lifecycle` parameter:

```swift
Guise.register(lifecycle: .cached) { Service() as Servicing }
```

This lazily creates our `Servicing` instance the first time one is needed. After that, the same instance is returned every time. It is possible when resolving to tell Guise _not_ to return the cached result, but instead to call the block again. _This does not overwrite the existing cached result, if any._

```swift
let service = Guise.resolve(lifecycle: .notCached)! as Servicing
```

Keep in mind that Guise registers blocks, _not_ instances. If we do something like this…

```swift
let service = Service()
Guise.register { service as Servicing }
```

then all talk of caching is irrelevant, because the same instance is returned every time. In fact, this is such a common case that Guise has an overload for it:

```swift
Guise.register(Service() as Servicing) // Note, however, that this dependency is not created lazily, but eagerly
```

There are three possible `Lifecycle` values: `.notCached` (the default), `.cached`, and `.once`. The meaning of the first two should be clear at this point. `.once` means that the dependency is removed right after it is resolved. If you pass `.once` when resolving, the dependency is also removed after it is resolved, even if it was registered as `.cached` or `.notCached`.

```swift
Guise.register(lifecycle: .cached) { Service() as Servicing } // Register a lazily created, cached dependency of type Servicing
let service = Guise.resolve(lifecycle: .once)! as Servicing // Returned and removed
Guise.register(42, name: "level", lifecycle: .once) // Register an Int named "level" that is removed right after it is resolved
```

The lifecycle can be specified when registering and when resolving. Here is what happens:

| Registering | Resolving | Effect |
| ----------- | --------- | ------ |
| `.notCached` | `.notCached` | resolution block is called |
| `.notCached` | `.cached` | resolution block is called; `.cached` ignored |
| `.notCached` | `.once` | resolution block is called; dependency removed |
| `.cached` | `.notCached` | resolution block is called; `.cached` ignored |
| `.cached` | `.cached` | cached value returned |
| `.cached` | `.once` | cached value returned; dependency removed |
| `.once` | _any_ | resolution block is called; dependency removed |

Cached values are resolved lazily, so obviously "cached value returned" implies that the resolution block will be called if the cached value has not yet been calculated.

#### Passing State

Another common scenario is passing state when resolving an instance. Perhaps our `Service` has a constructor that requires some value(s):

```swift
Guise.register { (tryCount: Int) in Service(tryCount: tryCount) as Servicing }
```

Resolution looks like this:

```swift
let service = Guise.resolve(7)! as Servicing
```

A few things to note:

- Only a single argument is supported. To pass multiple arguments, use a tuple, array, dictionary, struct, or some other complex type.
- When resolving, the same (or a compatible) type must be passed as the first argument of `resolve`, where compatibility is determined by the Swift language itself.

Here's a more complex example:

```swift
typealias Credentials = (username: String, password: String)
Guise.register { (credentials: Credentials) in Authenticator(username: credentials.username, password: credentials.password) as Authenticating }

// Later:
let credentials = (username: "guise", password: "password")
let authenticator = Guise.resolve(credentials)! as Authenticating
authenticator.authenticate()
```

### Names

It is possible to distinguish multiple similar registrations by using a name. For instance,

```swift
Guise.register(NSBundle.mainBundle(), name: "main")
Guise.register(name: "parameterized") { (credentials: Credentials) in Authenticator(username: credentials.username, password: credentials.password) as Authenticating }
Guise.register(lifecycle: .cached) { Authenticator() as Authenticating }
```

To resolve these instances:

```swift
let mainBundle = Guise.resolve(name: "main")! as NSBundle
let parameterizedAuthenticator = Guise.resolve(credentials, name: "parameterized")! as Authenticating
let authenticator = Guise.resolve()! as Authenticating
```

It is the combination of the type and the name that forms the registration key. Blocks with different return types registered under the same name do not conflict:

```swift
// These two are separate registrations because they register different types
Guise.register(7, name: "arg")
Guise.register("seven", name: "arg")
// This overwrites the registration of 7 above, because it's the same name and type
Guise.register(8, name: "arg")
```

### Keys

Every registered dependency is identified by a key, represented by the `Key` type in Guise. While it's uncommon to work with keys directly, the `register` method returns the key created when the dependency is registered:

```swift
let key = Guise.register { Foo() as Bar }
```

The key consists of the string representation of the registered type—in this case `Bar`, not `Foo`—, the name (if specified), and the container (discussed below). For any given dependency, the combination of these three items must be unique. Registering a dependency with the same key as an existing one overwrites the prior dependency, which may or may not be desired.

There are methods that can be used to unregister a dependency given its key:

```swift
Guise.unregister(key)
```

### Containers

Containers group related dependencies together by adding another string to the key that represents a dependency.

```swift
Guise.register(container: "AwesomeViewController") { Foo() as Bar }
Guise.reset("AwesomeViewController") // Removes all dependencies in the given container
```

As a convenience for registering many dependencies in a single container, you can use the `Container` type:

```swift
let container = Guise.container("AwesomeViewController")
container.register { Foo() as Bar }
container.register { Ding() as Dong }
```

You can also use containers to register multiple dependencies with the same lifecycle, e.g.,

```swift
let container = Guise.container(nil, lifecycle: .once) // Gets the default container
container.register(90, name: "argument1") // Register with .once lifecycle
container.register("age", name: "argument2") // Also registered with .once lifecycle
// However…
Guise.register(42, name: "level") // Registered with .NotCached lifecycle in the default container
```

### Resolution vs Injection

Dependency resolution is inferior to dependency injection, because it creates a dependency on the resolver. Unfortunately, as of this writing, Swift does not support the features necessary to make dependency injection possible. As soon as it does, I will transform Guise into a dependency injection framework!
