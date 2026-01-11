import Foundation

/// データレスポンス - 従来のリクエスト-レスポンス型
///
/// 単一のレスポンスボディを持つ通常のHTTPレスポンス。
/// JSONレスポンス、HTML、バイナリデータなどを返す際に使用。
public protocol DataResponse: ServerResponse, HeaderModifiableResponse {
    /// レスポンスボディ
    var body: Data { get }
}

// MARK: - Basic Implementation

/// 基本的なデータレスポンス実装
///
/// 汎用的なHTTPレスポンスを表現する値型。
/// JSON、HTML、プレーンテキストなど様々な形式のレスポンスに使用可能。
public struct BasicDataResponse: DataResponse {
    public let status: HTTPStatus
    public let headers: [String: String]
    public let body: Data

    public init(
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// JSONレスポンスを作成
    public init<T: Encodable>(
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        json value: T,
        encoder: JSONEncoder = .apiDefault
    ) throws {
        self.status = status
        var headers = headers
        headers["Content-Type"] = "application/json"
        self.headers = headers
        self.body = try encoder.encode(value)
    }

    /// ヘッダーを追加したレスポンスを返す
    public func withAddedHeaders(_ additionalHeaders: [String: String]) -> BasicDataResponse {
        var newHeaders = headers
        for (key, value) in additionalHeaders {
            newHeaders[key] = value
        }
        return BasicDataResponse(status: status, headers: newHeaders, body: body)
    }
}

// MARK: - JSON Encoder Extension

extension JSONEncoder {
    /// APIデフォルトのJSONEncoder設定
    public static var apiDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
