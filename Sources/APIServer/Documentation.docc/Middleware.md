# ミドルウェア

リクエスト/レスポンスパイプラインにミドルウェアを追加する方法を学びます。

## Overview

APIServerは、リクエストとレスポンスの処理をカスタマイズするための
ミドルウェアシステムを提供しています。

## 組み込みミドルウェア

### CORSMiddleware

Cross-Origin Resource Sharing（CORS）の設定：

```swift
app.middleware.use(CORSMiddleware(
    allowedOrigins: ["https://example.com", "https://api.example.com"],
    allowedMethods: [.GET, .POST, .PUT, .DELETE],
    allowedHeaders: ["Content-Type", "Authorization"],
    allowCredentials: true
))
```

すべてのオリジンを許可する場合：

```swift
app.middleware.use(CORSMiddleware(allowedOrigins: ["*"]))
```

### AuthMiddleware

Bearer トークン認証：

```swift
struct MyAuthProvider: AuthenticationProvider {
    func authenticate(token: String) async throws -> String? {
        // トークンを検証してユーザーIDを返す
        guard token == "valid-token" else { return nil }
        return "user-123"
    }
}

app.middleware.use(AuthMiddleware(provider: MyAuthProvider()))
```

### APIContractErrorMiddleware

APIContractError を JSON レスポンスに変換：

```swift
app.middleware.use(APIContractErrorMiddleware())
```

これにより、以下のようなエラーレスポンスが生成されます：

```json
{
    "error": "invalidInput",
    "message": "User ID must be a positive integer"
}
```

## カスタムミドルウェア

独自のミドルウェアを実装する場合：

```swift
struct LoggingMiddleware: ServerMiddleware {
    func respond(
        to request: ServerRequest,
        chainingTo next: @escaping (ServerRequest) async throws -> ServerResponse
    ) async throws -> ServerResponse {
        // リクエスト前の処理
        print("Request: \(request.method) \(request.url)")

        // 次のミドルウェアまたはハンドラを呼び出し
        let response = try await next(request)

        // レスポンス後の処理
        print("Response: \(response.status)")

        return response
    }
}

app.middleware.use(LoggingMiddleware())
```

## ミドルウェアの順序

ミドルウェアは登録された順序で実行されます。
一般的な推奨順序：

1. `CORSMiddleware` - CORS ヘッダーを最初に設定
2. `LoggingMiddleware` - リクエストのログ記録
3. `AuthMiddleware` - 認証チェック
4. `APIContractErrorMiddleware` - エラーハンドリング（最後）

```swift
app.middleware.use(CORSMiddleware(allowedOrigins: ["*"]))
app.middleware.use(LoggingMiddleware())
app.middleware.use(AuthMiddleware(provider: MyAuthProvider()))
app.middleware.use(APIContractErrorMiddleware())
```
