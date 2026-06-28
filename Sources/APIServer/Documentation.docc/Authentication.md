# 認証

Bearer トークンによる認証を実装する方法。

## Overview

APIServer は、`AuthenticationProvider` プロトコルと `server.useAuth(provider:)` を使って
柔軟な認証システムを提供する。

## AuthenticationProvider の実装

認証ロジックをカスタマイズするには `AuthenticationProvider` を実装する。
`verifyToken(_:)` がトークンを検証し、成功時はユーザー ID を返す（失敗時は `throw`）：

```swift
struct MyAuthProvider: AuthenticationProvider {
    func verifyToken(_ token: String) async throws -> String {
        // トークンを検証してユーザー ID を返す
        // 無効なトークンの場合は throw する
        guard let userId = try? verifyJWT(token) else {
            throw AuthenticationError.invalidToken("Invalid JWT")
        }
        return userId
    }
}
```

## 認証ミドルウェアの設定

`server.useAuth(provider:)` で認証を有効化する：

```swift
let server = try await Server.create()

server.useAuth(MyAuthProvider())
server.useErrorMiddleware()  // 認証エラーを JSON レスポンスに変換
```

## 認証状態へのアクセス

APIService ハンドラ内では `ServiceContext` から認証情報を取得する。
`context.userId` で認証済みユーザー ID（未認証時は `nil`）にアクセスできる：

```swift
func getProfile(input: ProfileInput, context: ServiceContext) async throws -> ProfileOutput {
    // 認証が必要なエンドポイント
    let userId = try context.requireUserId()  // 未認証なら HTTPError.unauthorized を throw

    // ユーザー情報を取得して返す
    let user = try await fetchUser(id: userId)
    return ProfileOutput(id: userId, name: user.name)
}
```

`context.userId` は任意アクセス（`nil` チェックが必要）、
`context.requireUserId()` は必須アクセス（未認証なら自動で 401 エラー）。

## Bearer トークン形式

認証ミドルウェアは以下の形式の `Authorization` ヘッダーを検出する：

```
Authorization: Bearer <token>
```

`<token>` の部分が `AuthenticationProvider.verifyToken(_:)` に渡される。
ヘッダーがない場合や検証失敗時でも次のハンドラに処理を渡す（エンドポイントの
`auth` 要件で最終的な認証チェックが行われる）。

## カスタム認証ミドルウェア

`ServerMiddleware` を実装して独自の認証ロジックを追加することも可能：

```swift
struct ConditionalAuthMiddleware: ServerMiddleware {
    let provider: any AuthenticationProvider
    let excludedPaths: Set<String>

    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        // 除外パスの場合は認証をスキップ
        if excludedPaths.contains(request.url.path) {
            return try await next(request)
        }

        // Authorization ヘッダーからトークンを抽出
        guard let authHeader = request.headers["Authorization"],
              authHeader.lowercased().hasPrefix("bearer ") else {
            return try await next(request)
        }

        let token = String(authHeader.dropFirst("bearer ".count))
        // カスタム認証ロジック...
        return try await next(request)
    }
}

server.use(ConditionalAuthMiddleware(
    provider: MyAuthProvider(),
    excludedPaths: ["/health", "/public"]
))
```
