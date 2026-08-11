internal import Vapor
import APIContract

/// Verifies a Bearer token and attaches the resulting user identity to the request.
///
/// This middleware never rejects a request. A missing header, a header that is not `Bearer`, and
/// a token the provider refuses all leave the request unauthenticated and continue down the chain;
/// the per-endpoint `auth` requirement is what turns that into `401`. Installed by
/// `ServerApplication.useAuth(_:)`.
struct AuthMiddleware<Provider: AuthenticationProvider>: AsyncMiddleware {
    private let provider: Provider

    init(provider: Provider) {
        self.provider = provider
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // The scheme is matched case-insensitively, but the token is taken from the original
        // header so its casing survives.
        if let authHeader = request.headers[.authorization].first,
           authHeader.lowercased().hasPrefix("bearer ") {
            let token = String(authHeader.dropFirst("bearer ".count))

            do {
                let userId = try await provider.verifyToken(token)
                request.auth.login(AuthenticatedUser(id: userId))
                request.logger.debug("Authenticated user: \(userId)")
            } catch {
                // Log and continue: the endpoint's auth requirement decides whether an
                // unauthenticated request is acceptable.
                request.logger.warning("Token verification failed: \(error)")
            }
        }

        return try await next.respond(to: request)
    }
}
