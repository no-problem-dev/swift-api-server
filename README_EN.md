# APIServer

English | [日本語](README.md)

An abstraction layer over the Vapor web framework. Keeps application code independent of Vapor-specific implementations.

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Vapor Abstraction**: Application code doesn't depend directly on Vapor
- **Protocol-Based Design**: Easy to test and extensible for the future
- **APIContract Integration**: Contract-based API definition with automatic routing
- **Middleware System**: CORS, authentication, and error handling included
- **Sendable Compliant**: Supports Swift 6's strict concurrency

## Quick Start

```swift
import APIServer
import APIContract

// API definition using APIContract
struct UserAPI: APIContract {
    static let method: HTTPMethodType = .get
    static let pathTemplate: String = "/users/:id"

    typealias PathInput = UserPathInput
    typealias QueryInput = EmptyInput
    typealias BodyInput = EmptyInput
    typealias Output = UserOutput
}

// Create and start the server
let app = try Server.create(environment: .detect())

// Mount the APIContract
try app.mount(UserAPI.self) { context in
    guard let id = Int(context.input.path.id) else {
        throw APIContractError.invalidInput(message: "Invalid user ID")
    }
    return UserOutput(id: id, name: "User \(id)")
}

// Add middleware
app.middleware.use(CORSMiddleware(allowedOrigins: ["*"]))
app.middleware.use(APIContractErrorMiddleware())

try await app.run()
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
    var routes: any RouteRegistrar { get }
    var logger: any ServerLogger { get }
    var middleware: MiddlewareConfiguration { get }

    func run() async throws
    func shutdown() async throws
}
```

### ServerEnvironment

Environment configuration abstraction:

```swift
let environment = ServerEnvironment.detect() // Auto-detect from ENVIRONMENT variable

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

Direct routes or using APIContract:

```swift
// Direct route registration
app.routes.get("health") { req async throws -> ServerResponse in
    BasicServerResponse(status: .ok, body: ["status": "healthy"])
}

// Using APIContract
app.mount(UserAPI.self) { context in
    UserOutput(id: 1, name: "User")
}
```

### Middleware

| Middleware | Purpose |
|------------|---------|
| `CORSMiddleware` | CORS header configuration |
| `AuthMiddleware` | Bearer token authentication |
| `APIContractErrorMiddleware` | Convert errors to JSON responses |

```swift
// CORS configuration
app.middleware.use(CORSMiddleware(
    allowedOrigins: ["https://example.com"],
    allowedMethods: [.GET, .POST, .PUT, .DELETE],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
))

// Authentication
app.middleware.use(AuthMiddleware(provider: MyAuthProvider()))

// Error handling
app.middleware.use(APIContractErrorMiddleware())
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

MIT License - See [LICENSE](LICENSE) for details.
