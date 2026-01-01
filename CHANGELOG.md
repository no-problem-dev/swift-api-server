# Changelog

このプロジェクトのすべての注目すべき変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。

## [未リリース]

<!-- 次のリリースに含める変更をここに追加 -->

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

[未リリース]: https://github.com/no-problem-dev/swift-api-server/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/no-problem-dev/swift-api-server/releases/tag/v1.0.0
