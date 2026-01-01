import Foundation
internal import Vapor
import APIContract

/// マウントされた API のルート群
///
/// `mount()` で作成され、API エンドポイントの登録を行います。
///
/// `APIRouteRegistrar` に準拠しているため、マクロが生成する
/// `registerAll()` メソッドを使用できます：
/// ```swift
/// FormulaAPI.registerAll(server.routes.mount(formulaService))
/// ```
public struct APIRoutes<Group: APIContractGroup, Service: APIService>: APIRouteRegistrar, @unchecked Sendable
where Service.Group == Group {
    let routes: RoutesBuilder

    /// サービスインスタンス
    public let service: Service

    init(routes: RoutesBuilder, service: Service) {
        self.routes = routes
        self.service = service
    }

    /// 個別のエンドポイントを登録する
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Endpoint.Output
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output: Encodable {
        routes.register(endpoint, handler: handler)
        return self
    }

    /// EmptyOutput を返すエンドポイントを登録する
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Void
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output == EmptyOutput {
        routes.register(endpoint, handler: handler)
        return self
    }
}
