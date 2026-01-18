# Changelog

このプロジェクトのすべての注目すべき変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。

## [未リリース]

なし

## [1.0.8] - 2026-01-18

### 追加

- **最大リクエストボディサイズ設定**: 大きなファイルアップロード（Base64画像など）に対応
  - `setMaxBodySize(_ bytes: Int)`: バイト数で指定
  - `setMaxBodySize(_ size: String)`: 文字列で指定（例: "10mb", "500kb", "1gb"）

### 使用例

```swift
let server = try await Server.create()
server.setMaxBodySize("10mb")  // 10MB まで受け付け
// or
server.setMaxBodySize(10 * 1024 * 1024)  // 10MB
```

## [1.0.7] - 2026-01-17

### 追加

- **Raw Webhook サポート**: Protobuf 等の非JSON形式のリクエストボディ対応
  - `RawWebhookRequest`: 生バイナリデータとヘッダーを保持する型
  - `Routes` プロトコルに `webhookRaw()` メソッドを追加
  - `VaporServerApplication`, `VaporRoutes`, `VaporRouteGroup`, `ServerRouteGroup` への実装
  - `WebhookBuilder.buildRawRequest` ヘルパーメソッド

### 使用例

```swift
// Eventarc Firestore トリガー（Protobuf形式）
routes.webhookRaw("firestore-event") { request in
    let event = try FirestoreProtobufDecoder.decode(request.data)
    let headers = CloudEventHeaders(from: request.headers.all)
    print("Event type: \(headers.type ?? "unknown")")
    // イベント処理...
    return HTTPStatus.ok
}
```

## [1.0.6] - 2026-01-17

### 追加

- **Webhook ルートサポート**: Eventarc/CloudEvents 統合用の Webhook エンドポイント機能
  - `WebhookRequest<Body>`: リクエストボディとヘッダーを保持する型
  - `WebhookHeaders`: HTTP ヘッダーアクセス用の型（大文字小文字を無視）
  - `Routes` プロトコルに `webhook()` メソッドを追加
  - ステータスのみ返すハンドラーとレスポンスボディ付きハンドラーの両方をサポート
  - `VaporRoutes`, `VaporRouteGroup`, `ServerRouteGroup` への実装

### 使用例

```swift
routes.webhook("user-created", body: AuthUserCreatedEvent.self) { request in
    let headers = CloudEventHeaders(from: request.headers.all)
    print("Event type: \(headers.type ?? "unknown")")
    return HTTPStatus.ok
}
```

## [1.0.5] - 2026-01-11

### 追加

- **SSEストリーミングサーバー**: Server-Sent Events (SSE) サーバー実装
  - `SSEEvent`: サーバー側SSEイベント（エンコード対応）
  - `SSERoutes`: `StreamingRouteRegistrar` 実装
  - `VaporSSEBuilder`: VaporのSSEレスポンスビルダー
  - `ServerResponse`/`DataResponse`/`StreamResponse`: レスポンス型抽象化

### 変更

- **ミドルウェア更新**: ストリーミングレスポンス対応
  - `ErrorMiddleware`: ストリーミングエラーハンドリング
  - `CORSMiddleware`: ストリーミング対応
  - `ServerMiddleware`: ストリーミング対応
  - `VaporServerApplication`: SSEルート登録統合

### テスト

- SSEイベントエンコーディングのテストを追加
- ルート登録のテストを追加

## [1.0.4] - 2026-01-10

### 修正

- **パスパラメータ解析の修正**: `pathTemplate` からパスパラメータを解析するように変更
  - ネストしたパスパラメータ（例: `/books/:bookId/chats` の `:bookId`）が正しく抽出されるように
  - `Request+Decode.swift` で `subPath` ではなく `pathTemplate` を使用
  - ネストしたエンドポイントのテストを追加

## [1.0.3] - 2026-01-01

### 変更

- **Handler → Service リネーム** (APIContract v1.0.3対応)
  - `RouteRegistrar` → `Routes` プロトコル
  - `MountedGroup` → `APIRoutes`
  - `VaporRouteRegistrar` → `VaporRoutes`
  - Handler参照をService パターンに更新

## [1.0.1] - 2026-01-01

### 変更

- **Vapor隠蔽**: `internal import Vapor` (SE-0409) により利用側で `import Vapor` が不要に
  - `VaporServerApplication.app` を `internal` に変更
  - `APIContractErrorMiddleware` を `internal` に変更（`server.useErrorMiddleware()` を使用）
  - `AuthMiddleware` を `internal` に変更（`server.useAuth()` を使用）
  - `AuthenticatedUser` を `internal` に変更
  - `Application` / `RoutesBuilder` の public extension を削除

## [1.0.0] - 2025-01-01

### 追加

- **ServerApplication プロトコル**: Vapor に依存しないサーバーアプリケーション抽象化
  - `routes`: ルート登録機能
  - `logger`: ログ機能
  - `middleware`: ミドルウェアチェーン
  - `run/shutdown`: サーバーライフサイクル管理

- **ServerEnvironment**: 環境設定の抽象化
  - `.development`, `.testing`, `.production`
  - `.detect()` による環境変数からの自動検出

- **ルーティングシステム**: RESTful API のルート定義
  - `RouteRegistrar` プロトコル
  - `RouteGroup` によるネストされたルーティング
  - HTTP メソッド対応: GET, POST, PUT, DELETE, PATCH

- **ミドルウェアシステム**: リクエスト/レスポンスパイプライン
  - `ServerMiddleware` プロトコル
  - `CORSMiddleware`: CORS 設定（オリジン、メソッド、ヘッダー、クレデンシャル）
  - `AuthMiddleware`: Bearer トークン認証
  - `APIContractErrorMiddleware`: エラーを JSON レスポンスに変換

- **APIContract 統合**: コントラクトベースの API 定義
  - `Application.mount(_:)` による APIContract マウント
  - 自動リクエストデコード（パス、クエリ、ボディ）
  - `HandlerContext` による認証状態管理

- **HTTPStatus**: 一般的な HTTP ステータスコード（17種類）

### ドキュメント

- README.md（日本語・英語）
- DESIGN.md（設計ドキュメント）
- DocC ドキュメント
- CHANGELOG.md（Keep a Changelog 形式）
- RELEASE_PROCESS.md

### テスト

- MountTests: ルートマウントと HTTP メソッドテスト
- AuthMiddlewareTests: 認証ミドルウェアテスト
- ErrorMiddlewareTests: エラーハンドリングテスト
- DecodeTests: リクエストパラメータデコードテスト

[未リリース]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.8...HEAD
[1.0.8]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.1...v1.0.3
[1.0.1]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-api-server/releases/tag/v1.0.0

<!-- Auto-generated on 2026-01-01T06:40:04Z by release workflow -->

<!-- Auto-generated on 2026-01-01T12:30:54Z by release workflow -->

<!-- Auto-generated on 2026-01-10T04:36:59Z by release workflow -->

<!-- Auto-generated on 2026-01-11T13:32:53Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:06:44Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:48:14Z by release workflow -->
