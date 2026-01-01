# ``APIServer``

Vaporウェブフレームワークの抽象化レイヤー。

@Metadata {
    @PageColor(blue)
}

## Overview

APIServerは、アプリケーションコードをVapor固有の実装から独立させるための抽象化レイヤーです。
プロトコルベースの設計により、テスト容易性と将来の拡張性を確保しています。

### 特徴

- **Vapor抽象化**: アプリケーションコードがVaporに直接依存しない
- **プロトコルベース設計**: テストしやすく、将来の拡張性を確保
- **APIContract統合**: コントラクトベースのAPI定義と自動ルーティング
- **ミドルウェアシステム**: CORS、認証、エラーハンドリングを標準装備
- **Sendable対応**: Swift 6の厳格な並行処理に対応

### クイックスタート

```swift
import APIServer
import APIContract

// サーバーの作成と起動
let app = try Server.create(environment: .detect())

// APIContractのマウント
try app.mount(UserAPI.self) { context in
    UserOutput(id: context.input.path.id, name: "User")
}

// ミドルウェアの追加
app.middleware.use(CORSMiddleware(allowedOrigins: ["*"]))
app.middleware.use(APIContractErrorMiddleware())

try await app.run()
```

## Topics

### はじめに

- <doc:GettingStarted>
- <doc:Architecture>

### コアコンポーネント

- ``ServerApplication``
- ``ServerEnvironment``
- ``ServerLogger``
- ``HTTPStatus``

### ルーティング

- ``RouteRegistrar``
- ``RouteGroup``
- ``MountedGroup``

### ミドルウェア

- ``ServerMiddleware``
- ``CORSMiddleware``
- ``AuthMiddleware``
- ``APIContractErrorMiddleware``
- <doc:Middleware>

### リクエスト/レスポンス

- ``ServerRequest``
- ``ServerResponse``
- ``BasicServerResponse``

### 認証

- ``AuthenticationProvider``
- ``AuthenticatedUser``
- <doc:Authentication>
