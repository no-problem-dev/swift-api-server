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
