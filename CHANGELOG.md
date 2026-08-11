# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [3.0.1] - 2026-08-11

### Fixed

- An endpoint is now satisfied only by a credential presented where its declared scheme puts it.
  A verified identity carries the scheme that proved it, and `buildServiceContext` requires that
  scheme to equal the one the endpoint declared, header name included. Previously the three
  authenticated schemes were interchangeable, so an `.apiKey` or `.queryParam` endpoint was let
  through by an `Authorization: Bearer` header — a credential in a position it never nominated.

  The reverse never happened and does not now: `AuthMiddleware` reads the `Authorization` header
  and nothing else, so a token in the query string has never authenticated anything. The new tests
  pin both directions.

  `AuthMiddleware` is still the only authenticator here, and it establishes `.bearer`. An endpoint
  declaring `.apiKey` or `.queryParam` therefore has nothing that can authenticate it and answers
  `401` until a middleware for that scheme is installed, rather than falling back to another
  scheme's credential.

## [3.0.0] - 2026-08-11

None

## [2.0.2] - 2026-07-19

### Changed

- Split the five types that shared the 400-line `VaporServerApplication.swift` into one file each.

## [2.0.1] - 2026-07-19

### Changed

- JSON response construction is now done in one place.
- Renamed `Request+Decode` to match what it actually does.

## [2.0.0] - 2026-07-19

### Changed

- Raised the `swift-api-contract` pin to 2.1.2, so a shared contract resolves in the same
  dependency graph as the client side. This package's own public API is unchanged; the major
  is the pinned dependency's major crossing over.
- Merged the duplicated `buildContext` implementations and corrected import placement.

## [1.0.9] - 2026-04-07

### Fixed

- Handle the new `AuthScheme` cases (`.bearer` / `.apiKey` / `.queryParam`).

## [1.0.8] - 2026-01-18

### Added

- **Maximum request body size setting**: for large file uploads (Base64 images and the like)
  - `setMaxBodySize(_ bytes: Int)`: specify in bytes
  - `setMaxBodySize(_ size: String)`: specify as a string (e.g. "10mb", "500kb", "1gb")

### Example

```swift
let server = try await Server.create()
server.setMaxBodySize("10mb")  // accept up to 10MB
// or
server.setMaxBodySize(10 * 1024 * 1024)  // 10MB
```

## [1.0.7] - 2026-01-17

### Added

- **Raw webhook support**: for non-JSON request bodies such as Protobuf
  - `RawWebhookRequest`: a type holding the raw binary data and the headers
  - Added a `webhookRaw()` method to the `Routes` protocol
  - Implementations in `VaporServerApplication`, `VaporRoutes`, `VaporRouteGroup`, `ServerRouteGroup`
  - `WebhookBuilder.buildRawRequest` helper method

### Example

```swift
// Eventarc Firestore trigger (Protobuf)
routes.webhookRaw("firestore-event") { request in
    let event = try FirestoreProtobufDecoder.decode(request.data)
    let headers = CloudEventHeaders(from: request.headers.all)
    print("Event type: \(headers.type ?? "unknown")")
    // handle the event...
    return HTTPStatus.ok
}
```

## [1.0.6] - 2026-01-17

### Added

- **Webhook route support**: webhook endpoints for Eventarc/CloudEvents integration
  - `WebhookRequest<Body>`: a type holding the request body and the headers
  - `WebhookHeaders`: a type for accessing HTTP headers (case-insensitive)
  - Added a `webhook()` method to the `Routes` protocol
  - Supports both status-only handlers and handlers with a response body
  - Implementations in `VaporRoutes`, `VaporRouteGroup`, `ServerRouteGroup`

### Example

```swift
routes.webhook("user-created", body: AuthUserCreatedEvent.self) { request in
    let headers = CloudEventHeaders(from: request.headers.all)
    print("Event type: \(headers.type ?? "unknown")")
    return HTTPStatus.ok
}
```

## [1.0.5] - 2026-01-11

### Added

- **SSE streaming server**: a Server-Sent Events (SSE) server implementation
  - `SSEEvent`: a server-side SSE event (encodable)
  - `SSERoutes`: a `StreamingRouteRegistrar` implementation
  - `VaporSSEBuilder`: Vapor's SSE response builder
  - `ServerResponse`/`DataResponse`/`StreamResponse`: response type abstractions

### Changed

- **Middleware updates**: support for streaming responses
  - `ErrorMiddleware`: streaming error handling
  - `CORSMiddleware`: streaming support
  - `ServerMiddleware`: streaming support
  - `VaporServerApplication`: SSE route registration integrated

### Tests

- Added tests for SSE event encoding
- Added tests for route registration

## [1.0.4] - 2026-01-10

### Fixed

- **Path parameter parsing**: parse path parameters from `pathTemplate`
  - Nested path parameters (e.g. `:bookId` in `/books/:bookId/chats`) are now extracted correctly
  - `Request+Decode.swift` uses `pathTemplate` instead of `subPath`
  - Added tests for nested endpoints

## [1.0.3] - 2026-01-01

### Changed

- **Handler → Service rename** (to follow APIContract v1.0.3)
  - `RouteRegistrar` → `Routes` protocol
  - `MountedGroup` → `APIRoutes`
  - `VaporRouteRegistrar` → `VaporRoutes`
  - Handler references updated to the Service pattern

## [1.0.1] - 2026-01-01

### Changed

- **Vapor is hidden**: `internal import Vapor` (SE-0409) removes the need for `import Vapor` on the calling side
  - `VaporServerApplication.app` is now `internal`
  - `APIContractErrorMiddleware` is now `internal` (use `server.useErrorMiddleware()`)
  - `AuthMiddleware` is now `internal` (use `server.useAuth()`)
  - `AuthenticatedUser` is now `internal`
  - Removed the public extensions on `Application` / `RoutesBuilder`

## [1.0.0] - 2025-01-01

### Added

- **ServerApplication protocol**: a server application abstraction that does not depend on Vapor
  - `routes`: route registration
  - `logger`: logging
  - `middleware`: the middleware chain
  - `run/shutdown`: server lifecycle management

- **ServerEnvironment**: an abstraction over environment configuration
  - `.development`, `.testing`, `.production`
  - Automatic detection from environment variables with `.detect()`

- **Routing system**: route definitions for RESTful APIs
  - `RouteRegistrar` protocol
  - Nested routing with `RouteGroup`
  - HTTP methods: GET, POST, PUT, DELETE, PATCH

- **Middleware system**: the request/response pipeline
  - `ServerMiddleware` protocol
  - `CORSMiddleware`: CORS configuration (origins, methods, headers, credentials)
  - `AuthMiddleware`: Bearer token authentication
  - `APIContractErrorMiddleware`: converts errors into JSON responses

- **APIContract integration**: contract-based API definitions
  - Mounting an APIContract with `Application.mount(_:)`
  - Automatic request decoding (path, query, body)
  - Authentication state management through `HandlerContext`

- **HTTPStatus**: the common HTTP status codes (17 of them)

### Documentation

- README.md (Japanese and English)
- DESIGN.md (design document)
- DocC documentation
- CHANGELOG.md (Keep a Changelog format)
- RELEASE_PROCESS.md

### Tests

- MountTests: route mounting and HTTP method tests
- AuthMiddlewareTests: authentication middleware tests
- ErrorMiddlewareTests: error handling tests
- DecodeTests: request parameter decoding tests

[Unreleased]: https://github.com/no-problem-dev/swift-api-server/compare/2.0.2...HEAD
[2.0.2]: https://github.com/no-problem-dev/swift-api-server/compare/2.0.1...2.0.2
[2.0.1]: https://github.com/no-problem-dev/swift-api-server/compare/2.0.0...2.0.1
[2.0.0]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.9...2.0.0
[1.0.9]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.1...v1.0.3
[1.0.1]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-api-server/releases/tag/v1.0.0

<!-- Auto-generated on 2026-01-01T06:40:04Z by release workflow -->

<!-- Auto-generated on 2026-01-01T12:30:54Z by release workflow -->

<!-- Auto-generated on 2026-01-10T04:36:59Z by release workflow -->

<!-- Auto-generated on 2026-01-11T13:32:53Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:06:44Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:48:14Z by release workflow -->

<!-- Auto-generated on 2026-01-18T03:14:03Z by release workflow -->
