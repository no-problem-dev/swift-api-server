# はじめに

APIServer を使って Vapor ベースのサーバーを構築する基本的な方法。

## Overview

APIServer は、Vapor ウェブフレームワークをラップしてアプリケーションコードから
Vapor 固有の実装を隠蔽するライブラリ。

## インストール

### Swift Package Manager

`Package.swift` に以下を追加する：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-api-server.git", from: "1.0.0")
]
```

ターゲットに追加：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "APIServer", package: "swift-api-server")
    ]
)
```

## 基本的な使い方

### サーバーの作成

`Server.create()` は非同期なので `async` コンテキストから呼び出す：

```swift
import APIServer

// 環境を自動検出してサーバーを作成
let server = try await Server.create()

// または明示的に環境を指定
let server = try await Server.create(environment: .development)
```

### ルートの登録

クロージャの戻り値は自動的に JSON エンコードされる：

```swift
// GET /health
server.get("health") {
    ["status": "healthy"]
}

// GET /users/:id（パスパラメータはルートパターンで指定）
server.get("users", ":id") {
    UserOutput(id: 1, name: "Alice")
}

// POST /items
server.post("items") {
    ItemOutput(id: 42, created: true)
}
```

### ルートグループ

共通プレフィックスを持つルートはグループ化できる：

```swift
let v1 = server.group("api", "v1")

v1.get("status") {
    ["version": "1.0"]
}

v1.post("echo") {
    EchoOutput(message: "ok")
}
```

### APIService を使ったルーティング

`APIContract` を使った型安全なルーティング。
`APIService` を実装したサービスを `routes.mount(_:)` で登録する：

```swift
import APIServer
import APIContract

// APIService の実装
struct UserService: APIService {
    typealias Group = UserAPIGroup
}

// マウントして registerAll で一括登録
let service = UserService()
UserAPIGroup.registerAll(server.routes.mount(service))
```

### サーバーの起動

```swift
try await server.run()
```

## 次のステップ

- <doc:Middleware>: ミドルウェアの設定方法
- <doc:Authentication>: 認証の実装方法
- <doc:Architecture>: 設計思想の詳細
