import APIContract

/// ルート登録プロトコル
///
/// HTTP ルートの登録機能を提供する抽象インターフェース。
public protocol Routes: Sendable {
    /// サブグループの型
    associatedtype Group: RouteGroup

    // MARK: - Simple Routes

    /// GET ルートを登録
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// POST ルートを登録
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// PUT ルートを登録
    @discardableResult
    func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// DELETE ルートを登録
    @discardableResult
    func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// PATCH ルートを登録
    @discardableResult
    func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    // MARK: - Webhook Routes

    /// Webhook POSTルートを登録
    ///
    /// リクエストボディとヘッダーの両方にアクセスできるエンドポイントを登録します。
    /// Eventarc や他のWebhookサービスからのイベント受信に使用します。
    @discardableResult
    func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self

    /// Webhook POSTルートを登録（レスポンスボディ付き）
    @discardableResult
    func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self

    /// Webhook POSTルートを登録（生バイナリデータ）
    ///
    /// Protobuf などの非JSON形式のリクエストボディを受け取るエンドポイントを登録します。
    /// Content-Type に関係なく、生のバイナリデータをそのまま渡します。
    @discardableResult
    func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self

    // MARK: - Grouping

    /// ルートグループを作成
    func group(_ path: String...) -> Group

    // MARK: - APIContract Mounting

    /// API グループをマウント（Service.Group から型推論）
    func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S>
}

/// ルートグループプロトコル
public protocol RouteGroup: Routes {}
