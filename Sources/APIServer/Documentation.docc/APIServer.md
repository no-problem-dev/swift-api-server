# ``APIServer``

Vapor ウェブフレームワークの抽象化レイヤー。

@Metadata {
    @PageColor(blue)
}

## Overview

APIServer は、アプリケーションコードを Vapor 固有の実装から独立させる抽象化レイヤー。
プロトコルベースの設計により、テスト容易性と将来の拡張性を確保する。

### 特徴

- **Vapor 抽象化**: アプリケーションコードが Vapor に直接依存しない
- **プロトコルベース設計**: テストしやすく、将来の拡張性を確保
- **APIContract 統合**: `APIService` ベースの自動ルーティング
- **ミドルウェアシステム**: CORS、認証、エラーハンドリングを標準装備
- **Sendable 対応**: Swift 6 の厳格な並行処理に対応

### クイックスタート

```swift
import APIServer

// サーバーを作成（非同期初期化）
let server = try await Server.create()

// ルートを登録
server.get("health") {
    ["status": "healthy"]
}

// ミドルウェアを追加
server.use(CORSServerMiddleware())
server.useErrorMiddleware()

// サーバーを起動
try await server.run()
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
- ``Server``

### ルーティング

- ``Routes``
- ``RouteGroup``
- ``ServerRouteGroup``
- ``APIRoutes``

### ミドルウェア

- ``ServerMiddleware``
- ``CORSServerMiddleware``
- ``CORSConfiguration``
- <doc:Middleware>

### リクエスト／レスポンス

- ``ServerRequest``
- ``ServerResponse``
- ``HeaderModifiableResponse``
- ``DataResponse``
- ``BasicDataResponse``
- ``StreamResponse``
- ``SSEStreamResponse``

### SSE（Server-Sent Events）

- ``SSEEvent``
- ``SSEEncodingError``
- ``SSEConstants``

### Webhook

- ``WebhookRequest``
- ``RawWebhookRequest``
- ``WebhookHeaders``

### 認証

- <doc:Authentication>
