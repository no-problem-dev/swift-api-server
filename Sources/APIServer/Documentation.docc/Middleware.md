# Middleware

Cross-cutting concerns, and the two things middleware here cannot do.

## Overview

A middleware sees every request before the route handler and every response after it. Register them
with `use(_:)`, in the order they should run: the first one added sees the request first and the
response last.

Two limits shape what belongs in a middleware:

- **The request cannot be rewritten.** ``ServerMiddleware/handle(request:next:)`` hands you a
  request and takes one back, but the original is what continues down the chain. Decorate the
  response, or reject the request — do not try to alter the input.
- **Path parameters are not available.** ``ServerRequest/pathParameters`` is always empty, because
  parameters are bound after the chain has run. Match on ``ServerRequest/url`` instead.

## Built-in middleware

### CORS

``CORSServerMiddleware`` answers preflights and attaches access-control headers to everything else.
A request whose method is `OPTIONS` is answered here and never reaches a handler, so an endpoint
cannot implement `OPTIONS` while it is installed.

```swift
server.use(CORSServerMiddleware(configuration: .custom(
    allowedOrigins: ["https://example.com", "https://api.example.com"],
    allowedMethods: [.get, .post, .put, .delete],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
)))
```

The default configuration permits every origin, which suits development and almost never suits a
deployed service:

```swift
server.use(CORSServerMiddleware())
```

Origin matching is exact — there is no wildcard within an entry, so `https://*.example.com` matches
nothing. An allowed origin is echoed back rather than answered with `*`, which is what makes
credentialed requests work; the flip side is that `allowedOrigins: ["*"]` together with
`allowCredentials: true` is accepted here and effectively trusts every origin.

### Authentication

``ServerApplication/useAuth(_:)`` installs Bearer-token verification. It annotates the request and
never rejects it — see <doc:Authentication>.

```swift
struct MyAuthProvider: AuthenticationProvider {
    func verifyToken(_ token: String) async throws -> String {
        guard token == "valid-token" else {
            throw AuthenticationError.invalidToken("Bad token")
        }
        return "user-123"
    }
}

server.useAuth(MyAuthProvider())
```

### Error handling

``ServerApplication/useErrorMiddleware()`` turns thrown errors into JSON bodies:

```swift
server.useErrorMiddleware()
```

```json
{
    "errorCode": "INVALID_INPUT",
    "message": "User ID must be a positive integer"
}
```

Four cases are handled. Contract errors keep their own status and error code. Framework abort
errors keep their status but report `VAPOR_ABORT` — which is what a malformed JSON body produces,
because the framework rejects it before decoding is attempted. A `DecodingError` that does reach
the middleware becomes `400` with the offending coding path in the message. Anything else becomes
`500` carrying `localizedDescription`, which for a plain Swift error is the type name rather than a
sentence — conform to `LocalizedError` if the message matters.

It only catches what is thrown after it, so register it before the routes it should cover.

## Writing your own

```swift
struct LoggingMiddleware: ServerMiddleware {
    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        print("Request: \(request.method) \(request.url)")

        let response = try await next(request)

        print("Response: \(response.status.code)")

        return response
    }
}

server.use(LoggingMiddleware())
```

Returning without calling `next` short-circuits the chain — that is how the CORS preflight answer
is produced. To add headers, return `response.addingHeaders(_:)`; the result reaches the wire
intact, streaming bodies included.

## Ordering

```swift
server.use(CORSServerMiddleware())     // outermost: headers on every response, including errors
server.use(LoggingMiddleware())        // sees the request early and the final status late
server.useAuth(MyAuthProvider())       // must run before handlers that read identity
server.useErrorMiddleware()            // innermost: catches only what is thrown after it
```
