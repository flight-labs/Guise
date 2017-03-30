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
- [x] Swift 3
- [x] Support for iOS 9+, macOS 10.11+, watchOS 2+, tvOS 9+

### Changes From Version 2.0

Guise 3.0 is not backwards-compatible with any previous version. The principle changes are these:

1. Containers have been eliminated as a separate type and are now just another `Hashable` parameter to the registration and resolution methods.
2. Caching has been simplified back to the state of affairs that existed in version 1.0. Instead of the complex lifecycles supported by version 2.0, there is only cached and not cached.
3. Names and containers can now be any `Hashable` type.
4. A set of `filter` overloads have been added which returns arrays of keys. This can be used for resolving or unregistering _en masse_.
5. The signatures of the `register` and `resolve` overloads have been updated as needed.

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

One common scenario is that we want to cache the result of the block and thereafter return only that result. This is supported with the `cached` parameter:

```swift
Guise.register(cached: true) { Service() as Servicing }
```

This lazily creates our `Servicing` instance the first time one is needed. After that, the same instance is returned every time. It is possible when resolving to tell Guise _not_ to return the cached result, but instead to call the block again. _This does not overwrite the existing cached result, if any._

```swift
let service = Guise.resolve(cached: false)! as Servicing
```

Keep in mind that Guise registers blocks, _not_ instances. If we do something like this…

```swift
let service = Service()
Guise.register { service as Servicing }
```

then all talk of caching is irrelevant, because the same instance is returned every time. In fact, this is such a common case that Guise has an overload for it:

```swift
Guise.register(instance: Service() as Servicing) // Note, however, that this dependency is not created lazily, but eagerly
```
#### Passing State

Another common scenario is passing state when resolving an instance. Perhaps our `Service` has a constructor that requires some value(s):

```swift
Guise.register { (tryCount: Int) in Service(tryCount: tryCount) as Servicing }
```

Resolution looks like this:

```swift
let service = Guise.resolve(parameter: 7)! as Servicing
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
let authenticator = Guise.resolve(parameter: credentials)! as Authenticating
authenticator.authenticate()
```

### Names and Containers

Simple registrations are distinguished only by the return type of the registration block, e.g.,

```swift
Guise.register(cached: true) { Service(99) as Servicing }
```

In this case, the block is registered under the type `Servicing`. If we attempt to register again with the same type, it will silently overwrite the previous registration:

```swift
Guise.register(cached: false) { Service(11) as Servicing }
```

We can distinguish multiple registrations using _names_ and _containers_. These are just additional parameters passed when registering and resolving. Any `Hashable` type—`String`, `Int`, an enumeration, and so on—may be used.

```swift
enum ServiceName { // This type is implicitly Hashable in Swift
case service33
}

Guise.register(name: "service99", cached: true) { Service(99) as Servicing }
Guise.register(name: ServiceName.service33, cached: true) { Service(33) as Servicing }
Guise.register(name: 11, cached; true) { Service(11) as Servicing }
```

These are all separate registrations and do not conflict. When resolving, the `name` must be specified.

```swift
guard let service = Guise.resolve(name: "service99") as Servicing? else { return }
```

Registrations can also be made in containers:

```swift
let container = "cool things"
Guise.register(instance: 7, container: container)
Guise.register(instance: 7, name: "seven", container: container)
```

Here we register the value 7 (an `Int`) twice in the same container, "cool things", but we distinguish the second registration with a name.

A name and container are required for every registration. When not specified, they default to the enumeration value `Name.default`.

### Keys

When a registration is made, a corresponding `Key` is generated. An instance of this type uniquely represents the registration and includes the type, name, and container under which the registration was made. If a registration is made which would produce the same key as an existing registration, the previous registration is overwritten. This is because Guise keeps registrations in a dictionary for which `Key` is the key.

`Key` is the return type of all the registration methods:

```swift
let key = Guise.register(name: "fred", container: Container.people) { Human() }
```

Most of the time keys can be ignored, but they can be used when resolving, e.g.,

```swift
let fred = Guise.resolve(key: key)! as Human
```

There's a slight danger here. If the wrong key is used, Guise may attempt to force-cast a value to `Human` that is not actually a `Human`. This will produce a runtime exception that cannot be caught, e.g.,

```swift
let key1 = Guise.register(name: "fred", container: Container.people) { Human() }
let key2 = Guise.register(name: "fido", container: Container.dogs) { Dog() }

let fido = Guise.resolve(key: key1)! as Dog
```

Because `key1` registers a `Human` instance, the code above will cause a runtime exception. It's better to do this instead:

```swift
let fido = Guise.resolve(name: "fido", container: Container.dogs)! as Dog
```

#### Creating Keys

A key is created and returned at the time of registration. But a key can still be created after the fact by creating an instance of `Key`.

```swift
let key1 = Key(type: Human.self, name: "fred", container: Container.people)
let key2 = Key(type: Int.self, name: Name.default, container: Name.default)
```

#### Finding Keys

The various `filter` overloads can be used to return arrays of keys. In the registration and resolution overloads, if a name or container is missing, it defaults to `Name.default`. However, with the `filter` overloads, the omission of these parameters means that they are simply ignored. For example,

```swift
let keys = Guise.filter(container: Container.people)
```

This will return _all_ keys registered in `Container.people`, regardless of type or name. This can be useful for mass resolution, as long as all of the keys register the same type.

```swift
let keys = Guise.filter(container: Container.people)
let humans = Guise.resolve(keys: keys) as [Human]
```

### Checking For The Existence of Registrations

Sometimes it is necessary to know whether there are any registrations of a certain type, or in a certain container, and so on. The `exists` overloads can handle this. Like `filter`, the absence of a name or container parameter does not default it to `Name.default`. Instead, it signifies that we do not care what the value of this parameter is.

```swift
if Guise.exists(container: Container.people) {
  print("We've got same people!")
}
```

If there are any keys registered in `Container.people`, regardless of type or name, this method returns true in the code above.

We could also use `filter` to achieve the same result, but `exists` is more efficient than `filter` because it returns as soon as a single match is found.

### Resolution vs Injection

Dependency resolution is inferior to dependency injection, because it creates a dependency on the resolver. Unfortunately, as of this writing, Swift does not support the features necessary to make dependency injection possible. As soon as it does, I will transform Guise into a dependency injection framework!
