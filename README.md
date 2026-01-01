# APIServer

[English](README_EN.md) | 日本語

Vapor ウェブフレームワークの抽象化レイヤー。アプリケーションコードを Vapor 固有の実装から独立させます。

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 特徴

- **Vapor 抽象化**: アプリケーションコードが Vapor に直接依存しない
- **プロトコルベース設計**: テストしやすく、将来の拡張性を確保
- **APIContract 統合**: コントラクトベースの API 定義と自動ルーティング
- **ミドルウェアシステム**: CORS、認証、エラーハンドリングを標準装備
- **Sendable 対応**: Swift 6 の厳格な並行処理に対応

## クイックスタート

```swift
import APIServer
import APIContract

// APIContract を使用した API 定義
struct UserAPI: APIContract {
    static let method: HTTPMethodType = .get
    static let pathTemplate: String = "/users/:id"

    typealias PathInput = UserPathInput
    typealias QueryInput = EmptyInput
    typealias BodyInput = EmptyInput
    typealias Output = UserOutput
}

// サーバーの作成と起動
let app = try Server.create(environment: .detect())

// APIContract のマウント
try app.mount(UserAPI.self) { context in
    guard let id = Int(context.input.path.id) else {
        throw APIContractError.invalidInput(message: "Invalid user ID")
    }
    return UserOutput(id: id, name: "User \(id)")
}

// ミドルウェアの追加
app.middleware.use(CORSMiddleware(allowedOrigins: ["*"]))
app.middleware.use(APIContractErrorMiddleware())

try await app.run()
```

## インストール

### Swift Package Manager

`Package.swift` に以下を追加：

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
    var routes: any RouteRegistrar { get }
    var logger: any ServerLogger { get }
    var middleware: MiddlewareConfiguration { get }

    func run() async throws
    func shutdown() async throws
}
```

### ServerEnvironment

環境設定の抽象化：

```swift
let environment = ServerEnvironment.detect() // ENVIRONMENT 環境変数から自動検出

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

直接ルートまたは APIContract を使用：

```swift
// 直接ルート登録
app.routes.get("health") { req async throws -> ServerResponse in
    BasicServerResponse(status: .ok, body: ["status": "healthy"])
}

// APIContract を使用
app.mount(UserAPI.self) { context in
    UserOutput(id: 1, name: "User")
}
```

### ミドルウェア

| ミドルウェア | 用途 |
|-------------|------|
| `CORSMiddleware` | CORS ヘッダー設定 |
| `AuthMiddleware` | Bearer トークン認証 |
| `APIContractErrorMiddleware` | エラーを JSON レスポンスに変換 |

```swift
// CORS 設定
app.middleware.use(CORSMiddleware(
    allowedOrigins: ["https://example.com"],
    allowedMethods: [.GET, .POST, .PUT, .DELETE],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
))

// 認証設定
app.middleware.use(AuthMiddleware(provider: MyAuthProvider()))

// エラーハンドリング
app.middleware.use(APIContractErrorMiddleware())
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

このライブラリは以下の原則に基づいて設計されています：

1. **依存性の隠蔽**: Vapor は `Internal/` ディレクトリ内に隠蔽され、公開 API には現れない
2. **プロトコル優先**: すべての抽象化は Swift プロトコルで定義
3. **Sendable 準拠**: すべての公開型は `Sendable` を採用
4. **ファクトリパターン**: `Server.create()` による依存性注入

詳細な設計ドキュメントは [DESIGN.md](DESIGN.md) を参照してください。

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| [swift-api-contract](https://github.com/no-problem-dev/swift-api-contract) | コントラクトベース API 定義 |
| [vapor](https://github.com/vapor/vapor) | 内部実装（公開 API には露出しない） |

## ドキュメント

詳細な API ドキュメントは [GitHub Pages](https://no-problem-dev.github.io/swift-api-server/documentation/apiserver/) で確認できます。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
