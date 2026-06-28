# APIServer

English | [日本語](./README.ja.md)

An abstraction layer over the Vapor web framework. Keeps application code independent of Vapor-specific implementations.

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Vapor Abstraction**: Application code doesn't depend directly on Vapor
- **Protocol-Based Design**: Easy to test and extensible for the future
- **APIContract Integration**: Type-safe routing via `APIService`
- **Middleware System**: CORS, authentication, and error handling included
- **Sendable Compliant**: Supports Swift 6's strict concurrency

## Quick Start

```swift
import APIServer

// Create a server (async initialization)
let server = try await Server.create()

// Register routes — closures are automatically JSON-encoded
server.get("health") {
    ["status": "healthy"]
}

// Add middleware
server.use(CORSServerMiddleware())
server.useErrorMiddleware()

// Start the server
try await server.run()
```

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-api-server.git", from: "1.0.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "APIServer", package: "swift-api-server")
    ]
)
```

## Core Components

### ServerApplication

Protocol definition for server applications:

```swift
public protocol ServerApplication: Sendable {
    associatedtype Routes: APIServer.Routes
    var environment: ServerEnvironment { get }
    var logger: ServerLogger { get }
    var routes: Routes { get }

    func use(_ middleware: any ServerMiddleware)
    func run() async throws
    func shutdown() async throws
}
```

The concrete implementation returned by `Server.create()` is `VaporServerApplication`.

### ServerEnvironment

Environment configuration abstraction. Auto-detected from the `SWIFT_ENV` or `VAPOR_ENV` environment variable:

```swift
let environment = ServerEnvironment.detect() // reads SWIFT_ENV or VAPOR_ENV

switch environment {
case .development:
    // Development settings
case .testing:
    // Testing settings
case .production:
    // Production settings
}
```

### Routing

Direct routes or `APIService`-based routing:

```swift
// Direct route registration
server.get("health") {
    ["status": "healthy"]
}

// Route group
let v1 = server.group("api", "v1")
v1.get("status") { ["version": "1.0"] }

// APIService-based routing
let service = MyAPIService()
MyAPIGroup.registerAll(server.routes.mount(service))
```

### Middleware

| Middleware | How to Add | Purpose |
|------------|-----------|---------|
| `CORSServerMiddleware` | `server.use(CORSServerMiddleware())` | CORS header configuration |
| Authentication | `server.useAuth(provider)` | Bearer token authentication |
| Error handling | `server.useErrorMiddleware()` | Convert errors to JSON responses |

```swift
// CORS configuration
server.use(CORSServerMiddleware(configuration: .custom(
    allowedOrigins: ["https://example.com"],
    allowedMethods: [.get, .post, .put, .delete],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
)))

// Authentication
server.useAuth(MyAuthProvider())  // MyAuthProvider: AuthenticationProvider

// Error handling
server.useErrorMiddleware()
```

### HTTPStatus

Common HTTP status codes:

| Status | Description |
|--------|-------------|
| `.ok` (200) | Success |
| `.created` (201) | Created |
| `.noContent` (204) | No Content |
| `.badRequest` (400) | Bad Request |
| `.unauthorized` (401) | Unauthorized |
| `.forbidden` (403) | Forbidden |
| `.notFound` (404) | Not Found |
| `.internalServerError` (500) | Internal Server Error |

## Design Philosophy

This library is designed based on the following principles:

1. **Dependency Hiding**: Vapor is hidden in the `Internal/` directory and doesn't appear in the public API
2. **Protocol First**: All abstractions are defined as Swift protocols
3. **Sendable Compliance**: All public types adopt `Sendable`
4. **Factory Pattern**: Dependency injection via `Server.create()`

See [DESIGN.md](DESIGN.md) for detailed design documentation.

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-api-contract](https://github.com/no-problem-dev/swift-api-contract) | Contract-based API definition |
| [vapor](https://github.com/vapor/vapor) | Internal implementation (not exposed in public API) |

## Documentation

Detailed API documentation is available at [GitHub Pages](https://no-problem-dev.github.io/swift-api-server/documentation/apiserver/).

## License

MIT License — See [LICENSE](LICENSE) for details.
