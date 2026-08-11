/// An HTTP status line — numeric code plus reason phrase — that keeps status handling
/// free of the underlying web framework's types.
///
/// Equality and hashing cover both stored properties, so a status built with the default
/// empty reason phrase is *not* equal to the matching constant: `HTTPStatus(code: 200) != .ok`.
/// Compare `code` directly when the phrase is irrelevant.
public struct HTTPStatus: Sendable, Equatable, Hashable {
    /// The numeric status code, such as `200` or `404`.
    public let code: Int

    /// The reason phrase sent alongside the code, empty when none was supplied.
    public let reasonPhrase: String

    /// Creates a status from a raw code.
    ///
    /// Prefer the static constants (`.ok`, `.notFound`, …) for standard codes; they carry the
    /// conventional reason phrase, which bare initialization does not.
    ///
    /// - Parameters:
    ///   - code: The numeric status code, such as `200` or `404`.
    ///   - reasonPhrase: The reason phrase; empty by default.
    public init(code: Int, reasonPhrase: String = "") {
        self.code = code
        self.reasonPhrase = reasonPhrase
    }

    // MARK: - 2xx Success

    /// 200 OK
    public static let ok = HTTPStatus(code: 200, reasonPhrase: "OK")

    /// 201 Created
    public static let created = HTTPStatus(code: 201, reasonPhrase: "Created")

    /// 202 Accepted
    public static let accepted = HTTPStatus(code: 202, reasonPhrase: "Accepted")

    /// 204 No Content
    public static let noContent = HTTPStatus(code: 204, reasonPhrase: "No Content")

    // MARK: - 3xx Redirection

    /// 301 Moved Permanently
    public static let movedPermanently = HTTPStatus(code: 301, reasonPhrase: "Moved Permanently")

    /// 302 Found
    public static let found = HTTPStatus(code: 302, reasonPhrase: "Found")

    /// 304 Not Modified
    public static let notModified = HTTPStatus(code: 304, reasonPhrase: "Not Modified")

    // MARK: - 4xx Client Error

    /// 400 Bad Request
    public static let badRequest = HTTPStatus(code: 400, reasonPhrase: "Bad Request")

    /// 401 Unauthorized
    public static let unauthorized = HTTPStatus(code: 401, reasonPhrase: "Unauthorized")

    /// 403 Forbidden
    public static let forbidden = HTTPStatus(code: 403, reasonPhrase: "Forbidden")

    /// 404 Not Found
    public static let notFound = HTTPStatus(code: 404, reasonPhrase: "Not Found")

    /// 405 Method Not Allowed
    public static let methodNotAllowed = HTTPStatus(code: 405, reasonPhrase: "Method Not Allowed")

    /// 409 Conflict
    public static let conflict = HTTPStatus(code: 409, reasonPhrase: "Conflict")

    /// 422 Unprocessable Entity
    public static let unprocessableEntity = HTTPStatus(code: 422, reasonPhrase: "Unprocessable Entity")

    /// 429 Too Many Requests
    public static let tooManyRequests = HTTPStatus(code: 429, reasonPhrase: "Too Many Requests")

    // MARK: - 5xx Server Error

    /// 500 Internal Server Error
    public static let internalServerError = HTTPStatus(code: 500, reasonPhrase: "Internal Server Error")

    /// 501 Not Implemented
    public static let notImplemented = HTTPStatus(code: 501, reasonPhrase: "Not Implemented")

    /// 502 Bad Gateway
    public static let badGateway = HTTPStatus(code: 502, reasonPhrase: "Bad Gateway")

    /// 503 Service Unavailable
    public static let serviceUnavailable = HTTPStatus(code: 503, reasonPhrase: "Service Unavailable")

    // MARK: - Helpers

    /// Whether the code falls in the 2xx range.
    public var isSuccess: Bool { (200..<300).contains(code) }

    /// Whether the code falls in the 3xx range.
    public var isRedirect: Bool { (300..<400).contains(code) }

    /// Whether the code falls in the 4xx range.
    public var isClientError: Bool { (400..<500).contains(code) }

    /// Whether the code falls in the 5xx range.
    public var isServerError: Bool { (500..<600).contains(code) }
}
