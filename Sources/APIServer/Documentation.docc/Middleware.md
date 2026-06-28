# ミドルウェア

リクエスト／レスポンスパイプラインにミドルウェアを追加する方法。

## Overview

APIServer は、リクエストとレスポンスの処理をカスタマイズするための
ミドルウェアシステムを提供する。

## 組み込みミドルウェア

### CORSServerMiddleware

Cross-Origin Resource Sharing（CORS）の設定。
`server.use(_:)` で追加する：

```swift
server.use(CORSServerMiddleware(configuration: .custom(
    allowedOrigins: ["https://example.com", "https://api.example.com"],
    allowedMethods: [.get, .post, .put, .delete],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
)))
```

すべてのオリジンを許可する場合（デフォルト設定）：

```swift
server.use(CORSServerMiddleware())
```

### 認証ミドルウェア

Bearer トークン認証。`server.useAuth(_:)` で追加する：

```swift
struct MyAuthProvider: AuthenticationProvider {
    func verifyToken(_ token: String) async throws -> String {
        guard token == "valid-token" else {
            throw AuthenticationError.invalidToken("Bad token")
        }
        return "user-123"
    }
}

server.useAuth(MyAuthProvider())
```

### エラーハンドリングミドルウェア

`APIContractError` を JSON レスポンスに変換する。
`server.useErrorMiddleware()` で追加する：

```swift
server.useErrorMiddleware()
```

これにより、以下のようなエラーレスポンスが生成される：

```json
{
    "errorCode": "INVALID_INPUT",
    "message": "User ID must be a positive integer"
}
```

## カスタムミドルウェア

`ServerMiddleware` を実装して独自のミドルウェアを作成する。
メソッド名は `handle(request:next:)`：

```swift
struct LoggingMiddleware: ServerMiddleware {
    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        // リクエスト前の処理
        print("Request: \(request.method) \(request.url)")

        // 次のミドルウェアまたはハンドラを呼び出し
        let response = try await next(request)

        // レスポンス後の処理
        print("Response: \(response.status.code)")

        return response
    }
}

server.use(LoggingMiddleware())
```

## ミドルウェアの順序

ミドルウェアは登録された順序で実行される。
一般的な推奨順序：

1. `CORSServerMiddleware` — CORS ヘッダーを最初に設定
2. カスタムロギングミドルウェア — リクエストのログ記録
3. `server.useAuth(_:)` — 認証チェック
4. `server.useErrorMiddleware()` — エラーハンドリング（最後）

```swift
server.use(CORSServerMiddleware())
server.use(LoggingMiddleware())
server.useAuth(MyAuthProvider())
server.useErrorMiddleware()
```
