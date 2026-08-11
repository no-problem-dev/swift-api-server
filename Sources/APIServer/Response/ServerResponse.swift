import Foundation

/// What every response has in common: a status, headers, and the ability to gain more headers.
///
/// Buffered and streaming bodies are separate protocols refining this one rather than a flag on a
/// single type, so a response that has no `body` cannot be asked for one. Middleware handles
/// responses as `any ServerResponse` and downcasts only when it needs the body.
public protocol ServerResponse: Sendable {
    /// The status to send.
    var status: HTTPStatus { get }

    /// The headers to send, found without regard to case.
    var headers: HTTPHeaderFields { get }

    /// Returns the response with the given headers applied, replacing any of the same name.
    ///
    /// This is a requirement of the base protocol on purpose. It was once an opt-in refinement,
    /// and responses that did not adopt it silently kept their original headers — which meant CORS
    /// headers vanished from streaming responses with nothing failing. As a base requirement,
    /// forgetting it is a compile error.
    ///
    /// - Parameter headers: Headers to add or replace.
    func addingHeaders(_ headers: HTTPHeaderFields) -> Self
}
