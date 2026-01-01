# Vapor抽象化設計書

## 目的

Backend（アプリケーション層）から素のVapor依存を排除し、`swift-api-server`が提供する抽象レイヤーのみを使用する設計に移行する。

## 現状の問題

```
Backend/Server
├── import Vapor ← 直接依存（問題）
├── configure.swift  → Application, Environment, CORSMiddleware
├── routes.swift     → RoutesBuilder, app.get(), app.grouped()
├── entrypoint.swift → @main, Environment.detect()
└── Shared+Content.swift → Content protocol conformance
```

## 目標アーキテクチャ

```
┌─────────────────────────────────────┐
│ Backend/Server (Application Code)   │
│ - No Vapor imports                   │
│ - Uses APIServer abstractions only   │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ swift-api-server                    │
│ ┌─────────────────────────────────┐ │
│ │ Public API (Abstractions)       │ │
│ │ - ServerApplication             │ │
│ │ - ServerRequest/Response        │ │
│ │ - ServerMiddleware              │ │
│ │ - RouteBuilder                  │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ Internal (Vapor Implementation) │ │
│ │ - VaporApplication              │ │
│ │ - VaporRequest/Response         │ │
│ │ - Vapor middleware adapters     │ │
│ └─────────────────────────────────┘ │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Vapor (Hidden dependency)           │
└─────────────────────────────────────┘
```

## 抽象化対象と設計

### Phase 1: Core Abstractions（必須）

#### 1.1 ServerApplication

```swift
// Public API
public protocol ServerApplication: Sendable {
    associatedtype Routes: RouteRegistrar

    var logger: ServerLogger { get }
    var routes: Routes { get }

    func middleware(_ middleware: any ServerMiddleware)
    func run() async throws
    func shutdown() async throws
}

// Factory for creating applications
public struct Server {
    public static func application(
        environment: ServerEnvironment = .detect()
    ) async throws -> some ServerApplication
}

// Environment abstraction
public enum ServerEnvironment: Sendable {
    case development
    case testing
    case production

    public static func detect() -> ServerEnvironment
}
```

**使用イメージ（Backend側）:**
```swift
// Before (Vapor直接)
@main
struct App {
    static func main() async throws {
        var env = try Environment.detect()
        let app = try await Application.make(env)
        try await configure(app)
        try await app.execute()
    }
}

// After (抽象化後)
@main
struct App {
    static func main() async throws {
        let server = try await Server.application()
        try await configure(server)
        try await server.run()
    }
}
```

#### 1.2 RouteRegistrar

```swift
public protocol RouteRegistrar: Sendable {
    associatedtype Group: RouteGroup

    // Simple route registration
    func get(_ path: String..., handler: @escaping @Sendable () async throws -> some Encodable & Sendable)
    func post(_ path: String..., handler: @escaping @Sendable () async throws -> some Encodable & Sendable)

    // Route grouping
    func group(_ path: String...) -> Group

    // APIContract mounting (既存)
    func mount<G: APIContractGroup, H: APIGroupHandler>(
        _ group: G.Type,
        handler: H
    ) -> MountedGroup<G, H> where H.Group == G
}

public protocol RouteGroup: RouteRegistrar {}
```

#### 1.3 ServerMiddleware

```swift
public protocol ServerMiddleware: Sendable {
    func handle(
        request: ServerRequest,
        next: @escaping @Sendable (ServerRequest) async throws -> ServerResponse
    ) async throws -> ServerResponse
}

// Built-in middleware
public struct CORSMiddleware: ServerMiddleware {
    public init(configuration: CORSConfiguration = .default())
}

public struct CORSConfiguration: Sendable {
    public static func `default`() -> CORSConfiguration
    public static func custom(
        allowedOrigins: [String],
        allowedMethods: [APIMethod],
        allowedHeaders: [String]
    ) -> CORSConfiguration
}
```

#### 1.4 ServerRequest / ServerResponse

```swift
public protocol ServerRequest: Sendable {
    var pathParameters: [String: String] { get }
    var queryParameters: [String: String] { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var url: URL { get }

    // Authentication
    func authenticatedUserId() -> String?
}

public protocol ServerResponse: Sendable {
    var status: HTTPStatus { get }
    var headers: [String: String] { get }
    var body: Data { get }
}

public struct HTTPStatus: Sendable, Equatable {
    public let code: Int
    public let reasonPhrase: String

    public static let ok = HTTPStatus(code: 200, reasonPhrase: "OK")
    public static let created = HTTPStatus(code: 201, reasonPhrase: "Created")
    public static let noContent = HTTPStatus(code: 204, reasonPhrase: "No Content")
    public static let badRequest = HTTPStatus(code: 400, reasonPhrase: "Bad Request")
    public static let unauthorized = HTTPStatus(code: 401, reasonPhrase: "Unauthorized")
    public static let notFound = HTTPStatus(code: 404, reasonPhrase: "Not Found")
    public static let internalServerError = HTTPStatus(code: 500, reasonPhrase: "Internal Server Error")
}
```

### Phase 2: Content Handling

#### 2.1 Content Protocol の除去

```swift
// Before: Vapor Content conformance required
extension WorkoutActivity: @retroactive Content {}

// After: Pure Codable (no Vapor dependency)
// WorkoutActivity already conforms to Codable - no changes needed
```

APIServerが内部でVaporのContent変換を行うため、アプリ側でのContent準拠は不要になる。

### Phase 3: Logging Abstraction

```swift
public protocol ServerLogger: Sendable {
    func trace(_ message: @autoclosure () -> String)
    func debug(_ message: @autoclosure () -> String)
    func info(_ message: @autoclosure () -> String)
    func warning(_ message: @autoclosure () -> String)
    func error(_ message: @autoclosure () -> String)
}
```

## 実装ファイル構成

```
swift-api-server/Sources/APIServer/
├── Core/
│   ├── ServerApplication.swift      # ServerApplication protocol + Server factory
│   ├── ServerEnvironment.swift      # ServerEnvironment enum
│   ├── ServerLogger.swift           # ServerLogger protocol
│   ├── HTTPStatus.swift             # HTTPStatus struct
│   └── HTTPHeaders.swift            # HTTPHeaders type
├── Routing/
│   ├── RouteRegistrar.swift         # RouteRegistrar protocol
│   ├── RouteGroup.swift             # RouteGroup protocol
│   └── MountedGroup.swift           # (existing) MountedGroup
├── Middleware/
│   ├── ServerMiddleware.swift       # ServerMiddleware protocol
│   ├── CORSMiddleware.swift         # CORSMiddleware implementation
│   ├── AuthMiddleware.swift         # (existing) AuthMiddleware
│   └── ErrorMiddleware.swift        # (existing, modify to use abstractions)
├── Request/
│   ├── ServerRequest.swift          # ServerRequest protocol
│   └── ServerResponse.swift         # ServerResponse protocol
├── Contract/
│   ├── Application+Mount.swift      # (existing) mount functionality
│   └── Request+Decode.swift         # (existing) decode functionality
└── Internal/
    └── Vapor/
        ├── VaporServerApplication.swift  # Vapor implementation
        ├── VaporRequest.swift            # Vapor Request adapter
        ├── VaporResponse.swift           # Vapor Response adapter
        └── VaporMiddleware.swift         # Vapor middleware adapter
```

## Backend移行後のコード例

### configure.swift

```swift
// Before
import APIServer
import Vapor  // ← 削除対象

func configure(_ app: Application) async throws {
    app.middleware.use(CORSMiddleware(configuration: .default()))
    app.middleware.use(APIContractErrorMiddleware())
    // ...
}

// After
import APIServer  // Vapor import不要

func configure(_ server: some ServerApplication) async throws {
    server.middleware(CORSMiddleware())
    server.middleware(APIContractErrorMiddleware())
    // ...
}
```

### routes.swift

```swift
// Before
import APIServer
import Vapor  // ← 削除対象

func routes(_ app: Application, ...) throws {
    app.get("health") { _ in "OK" }
    app.grouped("v1").get("status") { _ in ["status": "running"] }

    let activitiesRoutes = app.mount(ActivitiesAPI.self, handler: handler)
    activitiesRoutes.register(ActivitiesAPI.List.self) { ... }
}

// After
import APIServer  // Vapor import不要

func routes(_ server: some ServerApplication, ...) throws {
    server.routes.get("health") { "OK" }
    server.routes.group("v1").get("status") { ["status": "running"] }

    let activitiesRoutes = server.routes.mount(ActivitiesAPI.self, handler: handler)
    activitiesRoutes.register(ActivitiesAPI.List.self) { ... }
}
```

### entrypoint.swift

```swift
// Before
import Vapor

@main
struct App {
    static func main() async throws {
        var env = try Environment.detect()
        LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)
        defer { Task { try? await app.asyncShutdown() } }
        try await configure(app)
        try await app.execute()
    }
}

// After
import APIServer

@main
struct App {
    static func main() async throws {
        let server = try await Server.application()
        try await configure(server)
        try await server.run()
    }
}
```

## 実装優先順位

### 高優先度（Phase 1）
1. `ServerApplication` protocol + `Server.application()` factory
2. `RouteRegistrar` protocol + route mounting
3. `ServerMiddleware` protocol adaptation
4. `CORSMiddleware` abstraction

### 中優先度（Phase 2）
5. `ServerLogger` abstraction
6. `HTTPStatus` / `HTTPHeaders` types
7. `ServerRequest` / `ServerResponse` protocols (for custom handlers)

### 低優先度（Phase 3）
8. Content protocol removal
9. Advanced routing features
10. Testing utilities

## 互換性維持

### 段階的移行
1. 新しい抽象化APIを追加（既存APIは維持）
2. Backendを新APIに移行
3. 古いAPIをdeprecated化
4. 次のメジャーバージョンで古いAPI削除

### 型エイリアスによる互換性
```swift
// 移行期間中の互換性維持
@available(*, deprecated, renamed: "ServerApplication")
public typealias VaporApplication = Application
```

## テスト戦略

### Unit Tests
- 各抽象化の動作テスト
- Vapor実装アダプターのテスト

### Integration Tests
- 完全なリクエスト/レスポンスサイクル
- ミドルウェアチェーン
- 認証フロー

### Migration Tests
- 旧APIと新APIの互換性テスト
- パフォーマンス比較

## 見積もり

| Phase | タスク | 複雑度 |
|-------|--------|--------|
| 1.1 | ServerApplication | 高 |
| 1.2 | RouteRegistrar | 中 |
| 1.3 | ServerMiddleware | 中 |
| 1.4 | ServerRequest/Response | 低 |
| 2.1 | Content除去 | 低 |
| 3.1 | ServerLogger | 低 |

## 今後の拡張性

この抽象化により以下が可能になる：
- Vapor以外のフレームワーク（Hummingbird等）への切り替え
- テスト用のモックサーバー実装
- サーバーレス環境（AWS Lambda等）への対応
