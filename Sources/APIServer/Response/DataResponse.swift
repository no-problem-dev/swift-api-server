import Foundation

/// A response whose body is known in full before it is sent.
///
/// Middleware that inspects or rewrites bodies downcasts to this; a streaming response will not
/// match, which is the point.
public protocol DataResponse: ServerResponse {
    /// The complete body, possibly empty. No `Content-Type` is implied — set it in `headers`.
    var body: Data { get }
}

// MARK: - Basic Implementation

/// The stock buffered response, used for anything from JSON to HTML to raw bytes.
public struct BasicDataResponse: DataResponse {
    public let status: HTTPStatus
    public let headers: HTTPHeaderFields
    public let body: Data

    /// Creates a response from raw bytes.
    ///
    /// - Parameters:
    ///   - status: The status to send; `.ok` by default.
    ///   - headers: The headers to send; none by default, including no `Content-Type`.
    ///   - body: The body bytes; empty by default.
    public init(
        status: HTTPStatus = .ok,
        headers: HTTPHeaderFields = [:],
        body: Data = Data()
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Creates a response by JSON-encoding a value.
    ///
    /// `Content-Type: application/json` is set here and overrides any `Content-Type` passed in
    /// `headers`.
    ///
    /// - Parameters:
    ///   - status: The status to send; `.ok` by default.
    ///   - headers: Additional headers; none by default.
    ///   - value: The value to encode into the body.
    ///   - encoder: The encoder to use; ISO 8601 dates by default.
    /// - Throws: Whatever `encoder` throws for a value it cannot encode.
    public init<T: Encodable>(
        status: HTTPStatus = .ok,
        headers: HTTPHeaderFields = [:],
        json value: T,
        encoder: JSONEncoder = .apiDefault
    ) throws {
        self.status = status
        var headers = headers
        headers["Content-Type"] = "application/json"
        self.headers = headers
        self.body = try encoder.encode(value)
    }

    /// Returns a copy carrying the given headers, replacing any of the same name.
    public func addingHeaders(_ additionalHeaders: HTTPHeaderFields) -> BasicDataResponse {
        BasicDataResponse(
            status: status,
            headers: headers.replacing(additionalHeaders),
            body: body
        )
    }
}

// MARK: - JSON Encoder Extension

extension JSONEncoder {
    /// An encoder that writes dates as ISO 8601 and leaves key names untouched.
    ///
    /// Every response this package encodes goes through it, so a client can rely on one date
    /// format across contract endpoints, plain routes and webhook replies alike.
    public static var apiDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
