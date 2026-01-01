# はじめに

APIServerを使ってVaporベースのサーバーを構築する基本的な方法を学びます。

## Overview

APIServerは、Vaporウェブフレームワークをラップしてアプリケーションコードから
Vapor固有の実装を隠蔽するライブラリです。

## インストール

### Swift Package Manager

`Package.swift`に以下を追加してください：

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

```swift
import APIServer

// 環境を自動検出してサーバーを作成
let app = try Server.create(environment: .detect())

// または明示的に環境を指定
let app = try Server.create(environment: .development)
```

### ルートの登録

直接ルートを登録する方法：

```swift
app.routes.get("health") { req async throws -> ServerResponse in
    BasicServerResponse(status: .ok, body: ["status": "healthy"])
}

app.routes.post("users") { req async throws -> ServerResponse in
    // リクエストの処理
    BasicServerResponse(status: .created, body: ["id": 1])
}
```

### APIContractを使用したルーティング

推奨されるアプローチは、APIContractを使用することです：

```swift
import APIServer
import APIContract

struct UserAPI: APIContract {
    static let method: HTTPMethodType = .get
    static let pathTemplate: String = "/users/:id"

    typealias PathInput = UserPathInput
    typealias QueryInput = EmptyInput
    typealias BodyInput = EmptyInput
    typealias Output = UserOutput
}

// APIContractのマウント
try app.mount(UserAPI.self) { context in
    guard let id = Int(context.input.path.id) else {
        throw APIContractError.invalidInput(message: "Invalid user ID")
    }
    return UserOutput(id: id, name: "User \(id)")
}
```

### サーバーの起動

```swift
try await app.run()
```

## 次のステップ

- <doc:Middleware>: ミドルウェアの設定方法
- <doc:Authentication>: 認証の実装方法
- <doc:Architecture>: 設計思想の詳細
