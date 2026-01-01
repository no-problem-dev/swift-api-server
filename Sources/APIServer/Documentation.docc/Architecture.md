# アーキテクチャ

APIServerの設計思想と内部構造を理解します。

## Overview

APIServerは、アプリケーションコードをVapor固有の実装から独立させることを
目的として設計されています。

## 設計原則

### 1. 依存性の隠蔽

Vaporは`Internal/`ディレクトリ内に隠蔽され、公開APIには現れません：

```
Sources/APIServer/
├── Core/                    # 公開プロトコル
│   ├── ServerApplication.swift
│   ├── ServerEnvironment.swift
│   └── HTTPStatus.swift
├── Internal/                # Vapor実装（非公開）
│   ├── VaporServerApplication.swift
│   └── VaporRouteRegistrar.swift
└── ...
```

### 2. プロトコル優先

すべての抽象化はSwiftプロトコルで定義されています：

```swift
public protocol ServerApplication: Sendable {
    var routes: any RouteRegistrar { get }
    var logger: any ServerLogger { get }
    var middleware: MiddlewareConfiguration { get }

    func run() async throws
    func shutdown() async throws
}

public protocol ServerMiddleware: Sendable {
    func respond(
        to request: ServerRequest,
        chainingTo next: @escaping (ServerRequest) async throws -> ServerResponse
    ) async throws -> ServerResponse
}
```

### 3. Sendable準拠

Swift 6の厳格な並行処理に対応するため、すべての公開型は`Sendable`を採用：

```swift
public struct HTTPStatus: Sendable, Equatable {
    public let code: Int
    public let reasonPhrase: String
}

public struct CORSMiddleware: ServerMiddleware, Sendable {
    // ...
}
```

### 4. ファクトリパターン

`Server.create()`による依存性注入を採用：

```swift
public enum Server {
    public static func create(environment: ServerEnvironment) throws -> any ServerApplication {
        try VaporServerApplication(environment: environment)
    }
}
```

これにより、将来的に異なる実装（Hummingbird等）への切り替えが容易になります。

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

この設計により、以下の拡張が可能です：

1. **別のWebフレームワーク**: Hummingbird等への移行
2. **サーバーレス**: AWS Lambda、Cloud Functions対応
3. **テストダブル**: モック実装によるユニットテスト
4. **カスタム実装**: 特定のユースケース向けの最適化

## 詳細情報

設計の詳細については、プロジェクトルートの
`DESIGN.md`を参照してください。
