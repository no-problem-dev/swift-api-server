# APIServer

English | [日本語](./README.ja.md)

Build an HTTP server in Swift whose application code names no web framework.

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **No framework in your signatures** — Vapor is imported internally and never appears in the public API, so application code compiles and tests without it
- **Contract-driven routing** — mount an `APIService` and its endpoints register in one call, with inputs decoded and authentication enforced from the contract
- **Handlers return values, not responses** — an `Encodable` return is JSON-encoded with ISO 8601 dates
- **Middleware for CORS, authentication and errors** — included, and extensible with your own
- **Server-Sent Events and webhooks** — stream an `AsyncSequence`, or take a delivery's headers and raw bytes
- **Strict concurrency** — every public type is `Sendable`

## Quick Start

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

## Documentation

[API reference and guides](https://no-problem-dev.github.io/swift-api-server/documentation/apiserver/) —
including getting started, middleware, authentication, and the architecture behind the abstraction.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-api-server.git", from: "2.0.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "APIServer", package: "swift-api-server")
    ]
)
```

## Requirements

| APIServer | Swift | Platforms |
|---|---|---|
| 2.x | 6.0+ | macOS 14+ · Linux |

## License

MIT. See [LICENSE](LICENSE).
