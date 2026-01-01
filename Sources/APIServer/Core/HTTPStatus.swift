/// HTTPステータスコード
public struct HTTPStatus: Sendable, Equatable, Hashable {
    public let code: Int
    public let reasonPhrase: String

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

    /// 成功ステータス（2xx）かどうか
    public var isSuccess: Bool { (200..<300).contains(code) }

    /// リダイレクトステータス（3xx）かどうか
    public var isRedirect: Bool { (300..<400).contains(code) }

    /// クライアントエラー（4xx）かどうか
    public var isClientError: Bool { (400..<500).contains(code) }

    /// サーバーエラー（5xx）かどうか
    public var isServerError: Bool { (500..<600).contains(code) }
}
