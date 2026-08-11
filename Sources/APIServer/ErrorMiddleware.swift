import Foundation
internal import Vapor
import APIContract

/// Converts every error thrown downstream into a JSON error body.
///
/// Four cases are handled, in order: contract errors keep their own status and error code;
/// framework abort errors keep their status but are reported as `VAPOR_ABORT`; decoding failures
/// become `400` with the offending coding path in the message; anything else becomes `500` with
/// `localizedDescription`, which for a plain Swift error is the type name rather than a
/// human-readable sentence. Installed by `ServerApplication.useErrorMiddleware()`.
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
            return try encodeAbortError(error, for: request)
        } catch let error as DecodingError {
            let httpError = HTTPError.badRequest(decodingErrorMessage(error))
            return try encodeErrorResponse(httpError, for: request)
        } catch {
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

