# アーキテクチャ

APIServer の設計思想と内部構造。

## Overview

APIServer は、アプリケーションコードを Vapor 固有の実装から独立させることを
目的として設計されている。

## 設計原則

### 1. 依存性の隠蔽

Vapor は `Internal/` ディレクトリ内に隠蔽され、公開 API には現れない：

```
Sources/APIServer/
├── Core/                    # 公開プロトコル
│   ├── ServerApplication.swift
│   ├── ServerEnvironment.swift
│   └── HTTPStatus.swift
├── Internal/                # Vapor 実装（非公開）
│   ├── VaporServerApplication.swift
│   └── VaporRoutes.swift
└── ...
```

### 2. プロトコル優先

すべての抽象化は Swift プロトコルで定義されている：

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

public protocol ServerMiddleware: Sendable {
    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse
}
```

### 3. Sendable 準拠

Swift 6 の厳格な並行処理に対応するため、すべての公開型は `Sendable` を採用：

```swift
public struct HTTPStatus: Sendable, Equatable {
    public let code: Int
    public let reasonPhrase: String
}

public struct CORSServerMiddleware: ServerMiddleware {
    // ...
}
```

### 4. ファクトリパターン

`Server.create()` による依存性注入を採用：

```swift
public enum Server {
    public static func create(
        environment: ServerEnvironment = .detect()
    ) async throws -> VaporServerApplication {
        try await VaporServerApplication(environment: environment)
    }
}
```

これにより、将来的に異なる実装（Hummingbird 等）への切り替えが容易になる。

## レイヤー構造

```
┌─────────────────────────────────────┐
│         Application Code            │
│  (APIContract, Business Logic)      │
├─────────────────────────────────────┤
│          APIServer                  │
│  (Protocols, Abstractions)          │
├─────────────────────────────────────┤
│         Internal/                   │
│    (Vapor Implementations)          │
├─────────────────────────────────────┤
│           Vapor                     │
│   (HTTP Server, Routing, etc.)      │
└─────────────────────────────────────┘
```

## 将来の拡張性

この設計により、以下の拡張が可能：

1. **別の Web フレームワーク**: Hummingbird 等への移行
2. **サーバーレス**: AWS Lambda、Cloud Functions 対応
3. **テストダブル**: モック実装によるユニットテスト
4. **カスタム実装**: 特定のユースケース向けの最適化

## 詳細情報

設計の詳細については、プロジェクトルートの `DESIGN.md` を参照すること。
