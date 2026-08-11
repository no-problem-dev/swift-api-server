import Foundation
internal import Vapor
import APIContract

struct VaporMiddlewareAdapter: AsyncMiddleware {
    let middleware: any ServerMiddleware
    let logger: Logger

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let serverRequest = VaporServerRequest(request: request)

        let serverResponse = try await middleware.handle(request: serverRequest) { _ in
            // The request the middleware passes in is discarded: the original request continues
            // down the chain, so a middleware cannot rewrite what the handler sees.
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
    /// A response that is none of the three recognized shapes — an `SSEStreamResponse`, for
    /// instance — reaches the client as headers with an empty body.
    static func toVaporResponse(_ serverResponse: any ServerResponse) -> Response {
        // Return the original object so a streaming body survives; its headers were already
        // mutated in place by `addingHeaders`.
        if let vaporResponse = serverResponse as? VaporResponse {
            return vaporResponse.response
        }

        // Here the added headers live only on the snapshot, so copy them onto the object that
        // will be written.
        if let anyStream = serverResponse as? AnyStreamResponse,
           let vaporResponse = anyStream.underlyingResponse as? Response {
            for (name, value) in anyStream.headers {
                vaporResponse.headers.replaceOrAdd(name: name, value: value)
            }
            return vaporResponse
        }

        if let dataResponse = serverResponse as? DataResponse {
            var headers = HTTPHeaders()
            for (key, value) in dataResponse.headers {
                headers.add(name: key, value: value)
            }
            return Response(
                status: HTTPResponseStatus(statusCode: dataResponse.status.code),
                headers: headers,
                body: .init(data: dataResponse.body)
            )
        }

        var headers = HTTPHeaders()
        for (key, value) in serverResponse.headers {
            headers.add(name: key, value: value)
        }
        return Response(
            status: HTTPResponseStatus(statusCode: serverResponse.status.code),
            headers: headers,
            body: .empty
        )
    }
}

