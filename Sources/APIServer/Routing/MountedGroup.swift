import Foundation
@_implementationOnly import Vapor
import APIContract

/// マウントされたAPIグループ
///
/// `mount()`で作成されたルートグループを表し、
/// `register()`でエンドポイントを登録できます。
public struct MountedGroup<Group: APIContractGroup, Handler: APIGroupHandler>: @unchecked Sendable
where Handler.Group == Group {
    let routes: RoutesBuilder
    let handler: Handler

    init(routes: RoutesBuilder, handler: Handler) {
        self.routes = routes
        self.handler = handler
    }

    /// 個別のエンドポイントを登録する
    ///
    /// ## 使用例
    /// ```swift
    /// server.routes.mount(ActivitiesAPI.self, handler: handler)
    ///     .register(ActivitiesAPI.List.self) { input, ctx in
    ///         try await handler.handle(input, context: ctx)
    ///     }
    /// ```
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, HandlerContext) async throws -> Endpoint.Output
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output: Encodable {
        routes.register(endpoint, handler: handler)
        return self
    }

    /// EmptyOutputを返すエンドポイントを登録する
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, HandlerContext) async throws -> Void
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output == EmptyOutput {
        routes.register(endpoint, handler: handler)
        return self
    }
}
