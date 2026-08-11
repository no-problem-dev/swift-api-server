# Authentication

Verify a Bearer token once, then let each endpoint decide what it requires.

## Overview

Authentication here is split in two. A middleware verifies the token and records who the caller is;
the endpoint's own `auth` requirement decides whether an unauthenticated caller is acceptable.
Nothing is rejected in the middleware, which is why a public and a protected route can sit side by
side behind the same authenticator.

## Implementing a provider

`AuthenticationProvider` has one job: turn a token into a user ID, or throw.

```swift
struct MyAuthProvider: AuthenticationProvider {
    func verifyToken(_ token: String) async throws -> String {
        guard let userId = try? verifyJWT(token) else {
            throw AuthenticationError.invalidToken("Invalid JWT")
        }
        return userId
    }
}
```

The thrown error never reaches the client. It is logged at warning level and the request continues
unauthenticated, so a caller sees `401` from the endpoint's requirement rather than the provider's
message. Put anything you need to diagnose into the thrown error, not into a hoped-for response.

## Installing the middleware

```swift
let server = try await Server.create()

server.useAuth(MyAuthProvider())
server.useErrorMiddleware()  // renders the resulting 401 as JSON
```

## The header it looks for

```
Authorization: Bearer <token>
```

The scheme is matched case-insensitively, so `bearer` works too. Everything after the first space
is passed to `verifyToken(_:)` verbatim, including any trailing whitespace. A missing header, a
different scheme, and a rejected token are all handled the same way: the request proceeds
unauthenticated.

## Reading identity in a handler

Contract handlers receive a `ServiceContext`:

```swift
func getProfile(input: ProfileInput, context: ServiceContext) async throws -> ProfileOutput {
    let userId = try context.requireUserId()  // throws HTTPError.unauthorized when anonymous

    let user = try await fetchUser(id: userId)
    return ProfileOutput(id: userId, name: user.name)
}
```

`context.userId` is the optional form; `context.requireUserId()` throws when there is no identity.
For an endpoint that declares an `auth` requirement, the check has already happened before the
handler runs — a request without an identity was rejected during dispatch, so `requireUserId()`
inside such a handler is belt and braces rather than the real gate.

All non-`none` requirements behave identically here. Whether an endpoint nominates a Bearer token,
an API key or a query parameter, the identity can only have come from the Bearer-token middleware,
which is the sole authenticator this package ships.

Plain routes and SSE routes get no such enforcement. Their context is `.anonymous` unless a token
was verified, and rejecting is entirely up to the handler:

```swift
server.sse("user", "events") { context in
    guard case .authenticated(let userId) = context else {
        throw HTTPError.unauthorized
    }
    return userEventStream(for: userId)
}
```

## Custom authentication

Implement ``ServerMiddleware`` when the built-in flow does not fit — for instance to skip
verification on a set of paths. Match on the URL: path parameters are bound after the chain has
run, so a middleware never sees them.

```swift
struct ConditionalAuthMiddleware: ServerMiddleware {
    let provider: any AuthenticationProvider
    let excludedPaths: Set<String>

    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable () async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        if excludedPaths.contains(request.url.path) {
            return try await next()
        }

        guard let authHeader = request.headers["Authorization"],
              authHeader.lowercased().hasPrefix("bearer ") else {
            return try await next()
        }

        let token = String(authHeader.dropFirst("bearer ".count))
        // Verify the token, and reject by throwing.
        return try await next()
    }
}

server.use(ConditionalAuthMiddleware(
    provider: MyAuthProvider(),
    excludedPaths: ["/health", "/public"]
))
```

A middleware cannot record an identity for later steps to read — `next` takes no request, and there
is no mutable slot on ``ServerRequest``. A custom authenticator can therefore only reject;
establishing identity for handlers goes through `useAuth(_:)`.
