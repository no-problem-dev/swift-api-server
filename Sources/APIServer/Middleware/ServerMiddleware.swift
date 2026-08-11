import Foundation

/// A step in the request/response chain, for concerns that cut across routes such as logging,
/// CORS or security headers.
///
/// Responses are handed over as existentials so a middleware works the same for buffered and
/// streaming bodies; downcast only when a specific representation is needed.
public protocol ServerMiddleware: Sendable {
    /// Handles one request, calling `next` to continue down the chain.
    ///
    /// Returning without calling `next` short-circuits the chain — that is how the CORS preflight
    /// answer is produced. Headers added to the returned response survive all the way to the wire,
    /// including on streaming bodies.
    ///
    /// `next` takes no request: the original one continues down the chain, so a middleware cannot
    /// rewrite what later steps and the handler see. Mutate the response instead, or reject the
    /// request outright.
    ///
    /// - Parameters:
    ///   - request: A read-only view of the incoming request.
    ///   - next: Continues to the next middleware, or to the route handler.
    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable () async throws -> any ServerResponse
    ) async throws -> any ServerResponse
}

/// The read-only view of a request that middleware sees, free of web-framework types.
///
/// There are no path parameters here on purpose. Middleware runs before route dispatch, which is
/// what binds them, so nothing could report them at this point — read the path out of `url`
/// instead. Handlers do get them: a contract endpoint's input is decoded from the matched route.
public protocol ServerRequest: Sendable {
    /// The percent-decoded query string, with the last occurrence winning for a repeated key.
    var queryParameters: [String: String] { get }

    /// The request headers, found without regard to the case the client sent them in.
    var headers: HTTPHeaderFields { get }

    /// The request body, or `nil` when the request has none.
    var body: Data? { get }

    /// The requested URL.
    var url: URL { get }

    /// The HTTP method, uppercased — compare against `"OPTIONS"`, `"POST"` and so on.
    var method: String { get }

    /// The identity established by an earlier middleware, or `nil` if the request is
    /// unauthenticated. Always `nil` for middleware registered before the authenticator.
    var authenticatedUserId: String? { get }
}
