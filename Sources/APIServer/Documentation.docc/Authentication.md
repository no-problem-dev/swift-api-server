# 認証

Bearer トークンによる認証を実装する方法を学びます。

## Overview

APIServerは、`AuthMiddleware`と`AuthenticationProvider`プロトコルを使用して
柔軟な認証システムを提供します。

## AuthenticationProvider の実装

認証ロジックをカスタマイズするには、`AuthenticationProvider`プロトコルを実装します：

```swift
struct MyAuthProvider: AuthenticationProvider {
    func authenticate(token: String) async throws -> String? {
        // トークンを検証
        // 有効な場合はユーザーIDを返す
        // 無効な場合はnilを返す

        // 例: JWTトークンの検証
        guard let userId = try? verifyJWT(token) else {
            return nil
        }
        return userId
    }
}
```

## AuthMiddleware の設定

```swift
let authProvider = MyAuthProvider()
app.middleware.use(AuthMiddleware(provider: authProvider))
```

## 認証状態へのアクセス

APIContract ハンドラ内で認証されたユーザーにアクセス：

```swift
try app.mount(ProfileAPI.self) { context in
    // 認証が必要なエンドポイント
    guard let userId = context.authenticatedUserId else {
        throw APIContractError.unauthorized(message: "Authentication required")
    }

    // ユーザー情報を取得して返す
    let user = try await fetchUser(id: userId)
    return ProfileOutput(id: userId, name: user.name)
}
```

## 認証のスキップ

特定のエンドポイントで認証をスキップするには、
`AuthMiddleware`を使用しないルートグループを作成するか、
ミドルウェア内で特定のパスを除外します：

```swift
struct ConditionalAuthMiddleware: ServerMiddleware {
    let provider: AuthenticationProvider
    let excludedPaths: Set<String>

    func respond(
        to request: ServerRequest,
        chainingTo next: @escaping (ServerRequest) async throws -> ServerResponse
    ) async throws -> ServerResponse {
        // 除外パスの場合は認証をスキップ
        if excludedPaths.contains(request.url.path) {
            return try await next(request)
        }

        // 通常の認証処理
        // ...
    }
}

app.middleware.use(ConditionalAuthMiddleware(
    provider: MyAuthProvider(),
    excludedPaths: ["/health", "/public"]
))
```

## Bearer トークン形式

`AuthMiddleware`は以下の形式のAuthorizationヘッダーを期待します：

```
Authorization: Bearer <token>
```

トークンの部分が`AuthenticationProvider.authenticate(token:)`メソッドに渡されます。
