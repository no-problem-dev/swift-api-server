# ``APIServer``

Build an HTTP server whose application code names no web framework.

@Metadata {
    @PageColor(blue)
}

## Overview

`APIServer` puts a protocol boundary in front of Vapor. Routes, middleware, requests and responses
are declared in terms of this package's own types, and the framework backing them stays internal —
so application code compiles, and can be tested, without importing Vapor at all.

Start from ``Server/create(environment:)``, register middleware and routes, then run:

```swift
import APIServer

let server = try await Server.create()

server.get("health") {
    ["status": "healthy"]
}

server.use(CORSServerMiddleware())
server.useErrorMiddleware()

try await server.run()
```

Handlers return `Encodable` values rather than responses. The value is JSON-encoded with ISO 8601
dates and answered as `200 OK`; to control the status, throw an error the error middleware maps, or
build a ``BasicDataResponse`` from a middleware.

Three route families cover the shapes a service needs beyond plain JSON:

- **Contract endpoints** — mount an `APIService` and let its group register every endpoint at once,
  with inputs decoded and authentication enforced from the contract.
- **Server-Sent Events** — `sse` and `ssePost` stream an `AsyncSequence` of ``SSEEvent`` and keep
  the connection open until the sequence finishes.
- **Webhooks** — deliveries decode from `snake_case` and hand the handler the headers alongside the
  body, or the raw bytes when a signature has to be verified.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>
- ``Server``
- ``ServerApplication``
- ``ServerEnvironment``
- ``ServerLogger``

### Routing

- ``Routes``
- ``RouteGroup``
- ``ServerRouteGroup``
- ``APIRoutes``

### Middleware and CORS

- <doc:Middleware>
- ``ServerMiddleware``
- ``CORSServerMiddleware``
- ``CORSConfiguration``

### Authentication and identity

- <doc:Authentication>

### Requests and Responses

- ``ServerRequest``
- ``ServerResponse``
- ``DataResponse``
- ``BasicDataResponse``
- ``HTTPHeaderFields``
- ``HTTPStatus``

### Server-Sent Events

- ``SSEEvent``
- ``SSEConstants``
- ``SSEEncodingError``

### Webhooks

- ``WebhookRequest``
- ``RawWebhookRequest``
