import Foundation

/// データレスポンス - 従来のリクエスト-レスポンス型
///
/// 単一のレスポンスボディを持つ通常のHTTPレスポンス。
/// JSONレスポンス、HTML、バイナリデータなどを返す際に使用。
public protocol DataResponse: ServerResponse {
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

    /// バイナリボディを持つレスポンスを作成する。
    ///
    /// - Parameters:
    ///   - status: HTTP ステータス（省略時 `.ok`）
    ///   - headers: HTTP ヘッダー（省略時 空）
    ///   - body: レスポンスボディのバイナリデータ（省略時 空）
    public init(
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Encodable な値を JSON エンコードしてレスポンスを作成する。
    ///
    /// `Content-Type: application/json` ヘッダーを自動で付与する。
    ///
    /// - Parameters:
    ///   - status: HTTP ステータス（省略時 `.ok`）
    ///   - headers: 追加 HTTP ヘッダー（省略時 空）
    ///   - value: JSON エンコードする値
    ///   - encoder: 使用する `JSONEncoder`（省略時 `.apiDefault`）
    /// - Throws: JSON エンコード失敗時
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
    public func addingHeaders(_ additionalHeaders: [String: String]) -> BasicDataResponse {
        var newHeaders = headers
        for (key, value) in additionalHeaders {
            newHeaders[key] = value
        }
        return BasicDataResponse(status: status, headers: newHeaders, body: body)
    }
}

// MARK: - JSON Encoder Extension

extension JSONEncoder {
    /// API 標準の `JSONEncoder` 設定。
    ///
    /// `Date` を ISO 8601 形式にエンコードする。
    public static var apiDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
