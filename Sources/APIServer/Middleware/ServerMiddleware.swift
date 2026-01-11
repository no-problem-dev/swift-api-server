import Foundation

/// サーバーミドルウェアプロトコル
///
/// リクエスト/レスポンス処理パイプラインに介入するミドルウェアの抽象インターフェース。
/// 認証、ロギング、CORS、エラーハンドリングなどの横断的関心事を実装します。
///
/// ## 設計思想
/// - レスポンス型はexistentialとして扱う（`any ServerResponse`）
/// - DataResponse/StreamResponse どちらでも透過的に動作
/// - 具体的な型が必要な場合はダウンキャストで対応
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

// MARK: - Response Header Utilities

extension ServerResponse {
    /// ヘッダーを追加したレスポンスを返す
    ///
    /// HeaderModifiableResponseに準拠している場合はその機能を使用。
    /// それ以外の場合は元のレスポンスをそのまま返す（ストリームの場合など）。
    public func addingHeaders(_ headers: [String: String]) -> any ServerResponse {
        if let modifiable = self as? any HeaderModifiableResponse {
            return modifiable.withAddedHeaders(headers) as any ServerResponse
        }
        // ストリームレスポンス等でヘッダー追加ができない場合は元を返す
        return self
    }
}
