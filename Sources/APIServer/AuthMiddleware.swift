@_implementationOnly import Vapor
import APIContract

/// 認証ミドルウェア
///
/// `AuthenticationProvider`を使用してBearerトークンを検証し、
/// 認証済みユーザーをリクエストに設定します。
///
/// 使用方法: `server.useAuth(provider)` を呼び出してください。
struct AuthMiddleware<Provider: AuthenticationProvider>: AsyncMiddleware {
    private let provider: Provider

    init(provider: Provider) {
        self.provider = provider
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Authorizationヘッダーからトークンを抽出
        if let authHeader = request.headers[.authorization].first,
           authHeader.lowercased().hasPrefix("bearer ") {
            let token = String(authHeader.dropFirst("bearer ".count))

            do {
                let userId = try await provider.verifyToken(token)
                // Vapor標準の認証機構を使用
                request.auth.login(AuthenticatedUser(id: userId))
                request.logger.debug("Authenticated user: \(userId)")
            } catch {
                // 認証失敗をログに記録するが、次のハンドラーに処理を渡す
                // エンドポイントのAuthRequirementで認証チェックが行われる
                request.logger.warning("Token verification failed: \(error)")
            }
        }

        return try await next.respond(to: request)
    }
}
