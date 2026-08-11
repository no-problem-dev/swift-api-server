# Getting Started

Stand up a server, register routes, and mount a contract service.

## Overview

This walks through the pieces in the order you meet them. It assumes the package is already a
dependency; see the README for the SwiftPM snippet.

## Creating a server

``Server/create(environment:)`` is asynchronous because the underlying server allocates its event
loops up front, so call it from an `async` context:

```swift
import APIServer

// Reads SWIFT_ENV, then VAPOR_ENV, falling back to .development
let server = try await Server.create()

// Or state the environment outright
let server = try await Server.create(environment: .production)
```

The environment is decided once, here. Detection is forgiving to a fault: an unrecognized value —
including a misspelling of `production` — yields `.development` with no warning.

## Registering routes

A handler returns an `Encodable` value, not a response. It is JSON-encoded with ISO 8601 dates and
answered as `200 OK`:

```swift
// GET /health
server.get("health") {
    ["status": "healthy"]
}

// GET /users/:id — the pattern declares the parameter
server.get("users", ":id") {
    UserOutput(id: 1, name: "Alice")
}

// POST /items
server.post("items") {
    ItemOutput(id: 42, created: true)
}
```

These plain routes cannot read the path parameter they declare; that is what contract endpoints are
for. Use them for fixed paths — health checks, readiness probes, version stamps.

To see who is calling, take a `ServiceContext`:

```swift
server.get("me") { context in
    guard case .authenticated(let userId) = context else {
        throw HTTPError.unauthorized
    }
    return try await fetchProfile(userId)
}
```

Nothing enforces authentication for a plain route — the context is `.anonymous` when no token was
verified, and rejecting is the handler's job.

## Grouping routes

A group prefixes everything registered on it, and groups nest:

```swift
let v1 = server.group("api", "v1")

v1.get("status") {
    ["version": "1.0"]
}

v1.post("echo") {
    EchoOutput(message: "ok")
}
```

``ServerRouteGroup`` — what `server.group(_:)` returns — covers GET, POST, SSE and webhook routes,
but not PUT, DELETE or PATCH, and it cannot mount a service. For those, group from the registrar
instead: `server.routes.group("api", "v1")`.

## Mounting a contract service

Contract endpoints are where inputs get decoded, path parameters get bound and authentication gets
enforced, all from the contract rather than from handler code:

```swift
import APIServer
import APIContract

struct UserService: APIService {
    typealias Group = UserAPIGroup
}

UserAPIGroup.registerAll(server.routes.mount(UserService()))
```

`mount(_:)` scopes the service to its group's base path but serves nothing on its own — the
endpoints still have to be registered. `registerAll` is generated from the contract and covers all
of them; registering by hand with `register(_:handler:)` works too, but nothing checks that the set
is complete, and an endpoint left out is simply not served.

## Adding middleware

Middleware runs in registration order — first added sees the request first and the response last:

```swift
server.use(CORSServerMiddleware())
server.useAuth(MyAuthProvider())
server.useErrorMiddleware()
```

## Running

```swift
try await server.run()
```

`run()` suspends until the server stops. Call `shutdown()` to stop it from elsewhere.

## Next steps

- <doc:Middleware>: the built-in middleware and how to write your own
- <doc:Authentication>: verifying tokens and reading identity in handlers
- <doc:Architecture>: what the abstraction buys, and where it is thinner than it looks
