# APIServer

[English](./README.md) | 日本語

アプリケーションコードにウェブフレームワークの名前を出さずに HTTP サーバーを書く。

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 特徴

- **シグネチャにフレームワークが出ない** — Vapor は内部で import され公開 API に現れないので、アプリ側は Vapor 無しでビルドもテストもできる
- **コントラクト駆動のルーティング** — `APIService` をマウントすれば、入力のデコードと認証チェックまでコントラクトから決まり、エンドポイントは一括登録される
- **ハンドラーはレスポンスではなく値を返す** — `Encodable` の戻り値が ISO 8601 の日付で JSON エンコードされる
- **CORS・認証・エラーのミドルウェア** — 標準で入っていて、自作のものも足せる
- **Server-Sent Events と Webhook** — `AsyncSequence` をそのまま流す。Webhook はヘッダーと生バイトを受け取れる
- **strict concurrency 対応** — 公開型はすべて `Sendable`

## クイックスタート

```swift
import APIServer

let server = try await Server.create()

server.get("health") {
    ["status": "healthy"]
}

server.use(CORSServerMiddleware())
server.useErrorMiddleware()

try await server.run()
```

## ドキュメント

[API リファレンスとガイド](https://no-problem-dev.github.io/swift-api-server/documentation/apiserver/) —
入門・ミドルウェア・認証・抽象化の設計まで。

## インストール

`Package.swift` に追加する：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-api-server.git", from: "2.0.0")
]
```

ターゲットにプロダクトを足す：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "APIServer", package: "swift-api-server")
    ]
)
```

## 動作環境

| APIServer | Swift | プラットフォーム |
|---|---|---|
| 2.x | 6.0+ | macOS 14+ |

## ライセンス

MIT。[LICENSE](LICENSE) を参照。
