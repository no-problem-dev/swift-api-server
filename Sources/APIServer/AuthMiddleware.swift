internal import Vapor
import APIContract

/// Verifies a Bearer token and attaches the resulting user identity to the request.
///
/// This is the authenticator for `AuthScheme.bearer`, and the only one shipped here. It reads the
/// credential from the `Authorization` header and nowhere else — a token in the query string or in
/// a custom header is not a Bearer credential and is never looked at, so it cannot authenticate
/// anything. The identity it stores is tagged `.bearer`, which is what stops an endpoint declaring
/// another scheme from being satisfied by it.
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
                request.auth.login(AuthenticatedUser(id: userId, scheme: .bearer))
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
