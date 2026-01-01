import Foundation

/// サーバーミドルウェアプロトコル
///
/// リクエスト/レスポンス処理パイプラインに介入するミドルウェアの抽象インターフェース。
/// 認証、ロギング、CORS、エラーハンドリングなどの横断的関心事を実装します。
public protocol ServerMiddleware: Sendable {
    /// ミドルウェア処理を実行
    ///
    /// - Parameters:
    ///   - request: サーバーリクエスト
    ///   - next: 次のミドルウェアまたはハンドラー
    /// - Returns: サーバーレスポンス
    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse
}

/// サーバーリクエストプロトコル
public protocol ServerRequest: Sendable {
    /// パスパラメータ
    var pathParameters: [String: String] { get }

    /// クエリパラメータ
    var queryParameters: [String: String] { get }

    /// HTTPヘッダー
    var headers: [String: String] { get }

    /// リクエストボディ
    var body: Data? { get }

    /// リクエストURL
    var url: URL { get }

    /// HTTPメソッド
    var method: String { get }

    /// 認証済みユーザーIDを取得
    var authenticatedUserId: String? { get }
}

/// サーバーレスポンスプロトコル
public protocol ServerResponse: Sendable {
    /// HTTPステータス
    var status: HTTPStatus { get }

    /// HTTPヘッダー
    var headers: [String: String] { get }

    /// レスポンスボディ
    var body: Data { get }
}

/// 基本的なレスポンス実装
public struct BasicServerResponse: ServerResponse {
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

    public init(
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        json: some Encodable
    ) throws {
        self.status = status
        var headers = headers
        headers["Content-Type"] = "application/json"
        self.headers = headers
        self.body = try JSONEncoder().encode(json)
    }
}
