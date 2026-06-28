# APIServer

[English](./README.md) | 日本語

Vapor ウェブフレームワークの抽象化レイヤー。アプリケーションコードを Vapor 固有の実装から独立させる。

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 特徴

- **Vapor 抽象化**: アプリケーションコードが Vapor に直接依存しない
- **プロトコルベース設計**: テストしやすく、将来の拡張性を確保
- **APIContract 統合**: `APIService` ベースの型安全なルーティング
- **ミドルウェアシステム**: CORS、認証、エラーハンドリングを標準装備
- **Sendable 対応**: Swift 6 の厳格な並行処理に対応

## クイックスタート

```swift
import APIServer

// サーバーを作成（非同期初期化）
let server = try await Server.create()

// ルートを登録（クロージャの戻り値は自動 JSON エンコード）
server.get("health") {
    ["status": "healthy"]
}

// ミドルウェアを追加
server.use(CORSServerMiddleware())
server.useErrorMiddleware()

// サーバーを起動
try await server.run()
```

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

## コアコンポーネント

### ServerApplication

サーバーアプリケーションのプロトコル定義：

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
```

`Server.create()` が返す具象実装は `VaporServerApplication`。

### ServerEnvironment

環境設定の抽象化。`SWIFT_ENV` または `VAPOR_ENV` 環境変数から自動検出：

```swift
let environment = ServerEnvironment.detect() // SWIFT_ENV または VAPOR_ENV を参照

switch environment {
case .development:
    // 開発環境の設定
case .testing:
    // テスト環境の設定
case .production:
    // 本番環境の設定
}
```

### ルーティング

直接ルートまたは `APIService` を使ったルーティング：

```swift
// 直接ルート登録
server.get("health") {
    ["status": "healthy"]
}

// ルートグループ
let v1 = server.group("api", "v1")
v1.get("status") { ["version": "1.0"] }

// APIService ベースのルーティング
let service = MyAPIService()
MyAPIGroup.registerAll(server.routes.mount(service))
```

### ミドルウェア

| ミドルウェア | 追加方法 | 用途 |
|-------------|---------|------|
| `CORSServerMiddleware` | `server.use(CORSServerMiddleware())` | CORS ヘッダー設定 |
| 認証 | `server.useAuth(provider)` | Bearer トークン認証 |
| エラーハンドリング | `server.useErrorMiddleware()` | エラーを JSON レスポンスに変換 |

```swift
// CORS 設定
server.use(CORSServerMiddleware(configuration: .custom(
    allowedOrigins: ["https://example.com"],
    allowedMethods: [.get, .post, .put, .delete],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
)))

// 認証設定
server.useAuth(MyAuthProvider())  // MyAuthProvider: AuthenticationProvider

// エラーハンドリング
server.useErrorMiddleware()
```

### HTTPStatus

一般的な HTTP ステータスコード：

| ステータス | 説明 |
|-----------|------|
| `.ok` (200) | 成功 |
| `.created` (201) | 作成成功 |
| `.noContent` (204) | コンテンツなし |
| `.badRequest` (400) | 不正なリクエスト |
| `.unauthorized` (401) | 認証が必要 |
| `.forbidden` (403) | アクセス禁止 |
| `.notFound` (404) | 見つからない |
| `.internalServerError` (500) | サーバーエラー |

## 設計思想

このライブラリは以下の原則に基づいて設計されている：

1. **依存性の隠蔽**: Vapor は `Internal/` ディレクトリ内に隠蔽され、公開 API には現れない
2. **プロトコル優先**: すべての抽象化は Swift プロトコルで定義
3. **Sendable 準拠**: すべての公開型は `Sendable` を採用
4. **ファクトリパターン**: `Server.create()` による依存性注入

詳細な設計ドキュメントは [DESIGN.md](DESIGN.md) を参照すること。

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| [swift-api-contract](https://github.com/no-problem-dev/swift-api-contract) | コントラクトベース API 定義 |
| [vapor](https://github.com/vapor/vapor) | 内部実装（公開 API には露出しない） |

## ドキュメント

詳細な API ドキュメントは [GitHub Pages](https://no-problem-dev.github.io/swift-api-server/documentation/apiserver/) で確認できる。

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照すること。
