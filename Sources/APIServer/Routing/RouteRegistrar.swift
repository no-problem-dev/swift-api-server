import APIContract

/// ルート登録プロトコル
///
/// HTTPルートの登録機能を提供する抽象インターフェース。
public protocol RouteRegistrar: Sendable {
    /// サブグループの型
    associatedtype Group: RouteGroup

    // MARK: - Simple Routes

    /// GETルートを登録
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// POSTルートを登録
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// PUTルートを登録
    @discardableResult
    func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// DELETEルートを登録
    @discardableResult
    func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// PATCHルートを登録
    @discardableResult
    func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    // MARK: - Grouping

    /// ルートグループを作成
    func group(_ path: String...) -> Group

    // MARK: - APIContract Mounting

    /// APIグループをマウント
    func mount<G: APIContractGroup, H: APIGroupHandler>(
        _ group: G.Type,
        handler: H
    ) -> MountedGroup<G, H> where H.Group == G
}

/// ルートグループプロトコル
public protocol RouteGroup: RouteRegistrar {}
