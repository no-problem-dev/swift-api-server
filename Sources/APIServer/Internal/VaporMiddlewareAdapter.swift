import Foundation
internal import Vapor
import APIContract

struct VaporMiddlewareAdapter: AsyncMiddleware {
    let middleware: any ServerMiddleware
    let logger: Logger

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let serverRequest = VaporServerRequest(request: request)

        let serverResponse = try await middleware.handle(request: serverRequest) {
            // The original request continues down the chain — a middleware cannot rewrite what
            // the handler sees, which is why `next` takes nothing.
            let response = try await next.respond(to: request)
            return VaporResponse(response: response)
        }

        return Self.toVaporResponse(serverResponse)
    }

    /// Lowers an abstract response to the one that is actually written.
    ///
    /// Every case has to carry over the headers a middleware added, or CORS and friends vanish
    /// without a trace. Split out of `respond` so it can be tested directly.
    ///
    /// A `ServerResponse` that is not a `DataResponse` has no body to write by definition, so it
    /// goes out as headers alone.
    static func toVaporResponse(_ serverResponse: any ServerResponse) -> Response {
        // Return the original object so a streaming body survives; its headers were already
        // mutated in place by `addingHeaders`.
        if let vaporResponse = serverResponse as? VaporResponse {
            return vaporResponse.response
        }

        if let dataResponse = serverResponse as? DataResponse {
            return Response(
                status: HTTPResponseStatus(statusCode: dataResponse.status.code),
                headers: vaporHeaders(from: dataResponse.headers),
                body: .init(data: dataResponse.body)
            )
        }

        return Response(
            status: HTTPResponseStatus(statusCode: serverResponse.status.code),
            headers: vaporHeaders(from: serverResponse.headers),
            body: .empty
        )
    }

    private static func vaporHeaders(from fields: HTTPHeaderFields) -> HTTPHeaders {
        var headers = HTTPHeaders()
        for (name, value) in fields.all {
            headers.add(name: name, value: value)
        }
        return headers
    }
}

