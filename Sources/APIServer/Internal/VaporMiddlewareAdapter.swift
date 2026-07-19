import Foundation
internal import Vapor
import APIContract

struct VaporMiddlewareAdapter: AsyncMiddleware {
    let middleware: any ServerMiddleware
    let logger: Logger

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let serverRequest = VaporServerRequest(request: request)

        let serverResponse = try await middleware.handle(request: serverRequest) { _ in
            // 次のミドルウェア/ハンドラーを呼び出し
            let response = try await next.respond(to: request)
            return VaporResponse(response: response)
        }

        // VaporResponseの場合、元のVapor Responseを返す
        // これによりストリーミングボディが保持される
        if let vaporResponse = serverResponse as? VaporResponse {
            return vaporResponse.response
        }

        // AnyStreamResponseの場合、内部のVapor Responseを返す
        if let anyStream = serverResponse as? AnyStreamResponse,
           let vaporResponse = anyStream.underlyingResponse as? Response {
            return vaporResponse
        }

        // BasicDataResponseなどの場合は変換
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

        // その他の場合はヘッダーのみ変換（ボディは空）
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

