Guise is an elegant, flexible, type-safe dependency resolution framework for Swift.

- [x] Flexible dependency creation, with optional caching
- [x] Simplifies unit testing
- [x] Pass arbitrary state when resolving
- [x] Support for iOS and OSX

### Usage

Guise supports two basic operations: registration and resolution. Registration is the act of registering a block whose return type is used as a key when resolution is needed. Resolution is the act of calling the registered lambda and returning its result.

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

Here, `Servicing` is a protocol. Guise hides the underlying type we are actually using so that we can easily replace it—for example, in unit tests.

```swift
Guise.register { FakeService() as Servicing }
// Later:
let service = Guise.resolve()! as Servicing
```

#### Caching

One common scenario is that we want to cache the result of the block and thereafter return only that instance. This is supported with the `cached` parameter:

```swift
Guise.register(cached: true) { Service() as Servicing }
```

This lazily creates our `Servicing` instance the first time one is needed. After that, the same instance is returned every time. It is possible when resolving to tell Guise _not_ to return the cached instance, but instead to call the block again. _This does not overwrite the existing cached instance, if any._

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
let service = Service()
Guise.register(service as Servicing)
```

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
Guise.register(cached: true) { Authenticator() as Authenticating }
```

To resolve these instances:

```swift
let mainBundle = Guise.resolve(name: "main")! as NSBundle
let parameterizedAuthenticator = Guise.resolve(credentials, name: "parameterized")! as Authenticating
let authenticator = Guise.resolve()! as Authenticating
```

It is the combination of the type and the name that forms the registration key. Blocks with different return types registered under the same name do not conflict.

### Resolution vs Injection

Dependency resolution is inferior to dependency injection, because it creates a dependency on the resolver. Unfortunately, as of this writing, Swift does not support the features necessary to make dependency injection possible.
