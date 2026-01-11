import Foundation
internal import Vapor
import APIContract

/// APIContract用のエラーミドルウェア
///
/// `APIContractError`をキャッチして適切なJSONレスポンスに変換します。
///
/// 使用方法: `server.useErrorMiddleware()` を呼び出してください。
struct APIContractErrorMiddleware: AsyncMiddleware {

    init() {}

    func respond(
        to request: Request,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as any APIContractError {
            return try encodeErrorResponse(error, for: request)
        } catch let error as AbortError {
            // VaporのAbortErrorをそのまま処理
            return try encodeAbortError(error, for: request)
        } catch let error as DecodingError {
            // デコーディングエラーをBad Requestとして処理
            let httpError = HTTPError.badRequest(decodingErrorMessage(error))
            return try encodeErrorResponse(httpError, for: request)
        } catch {
            // その他のエラーは500 Internal Server Error
            let httpError = HTTPError.internalError(error.localizedDescription)
            return try encodeErrorResponse(httpError, for: request)
        }
    }

    // MARK: - Private Helpers

    private func encodeErrorResponse(
        _ error: some APIContractError,
        for request: Request
    ) throws -> Response {
        let errorResponse = error.toErrorResponse()
        let encoder = JSONEncoder.apiDefault
        let data = try encoder.encode(errorResponse)

        var headers = HTTPHeaders()
        headers.contentType = .json

        return Response(
            status: HTTPResponseStatus(statusCode: error.statusCode),
            headers: headers,
            body: .init(data: data)
        )
    }

    private func encodeAbortError(
        _ error: AbortError,
        for request: Request
    ) throws -> Response {
        let errorResponse = ErrorResponse(
            errorCode: "VAPOR_ABORT",
            message: error.reason
        )
        let encoder = JSONEncoder.apiDefault
        let data = try encoder.encode(errorResponse)

        var headers = HTTPHeaders()
        headers.contentType = .json

        return Response(
            status: error.status,
            headers: headers,
            body: .init(data: data)
        )
    }

    private func decodingErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return "Unknown decoding error"
        }
    }
}

