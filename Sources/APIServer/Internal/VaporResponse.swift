import Foundation
internal import Vapor
import APIContract

/// Presents the framework's own response through the abstract interface, without copying it.
///
/// This is what a handler's response is wrapped in on the way back up the middleware chain, so a
/// streaming body keeps streaming.
struct VaporResponse: ServerResponse {
    let response: Response

    var status: HTTPStatus {
        HTTPStatus(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase)
    }

    var headers: [String: String] {
        var result: [String: String] = [:]
        for (name, value) in response.headers {
            result[name] = value
        }
        return result
    }

    /// Applies the headers to the wrapped response and returns `self`.
    ///
    /// The wrapped response is a reference type, so this mutates in place rather than copying —
    /// which is what keeps a streaming body intact. The value discarded by a caller that ignores
    /// the result has been modified all the same.
    func addingHeaders(_ additionalHeaders: [String: String]) -> VaporResponse {
        for (key, value) in additionalHeaders {
            response.headers.replaceOrAdd(name: HTTPHeaders.Name(key), value: value)
        }
        return self
    }
}
