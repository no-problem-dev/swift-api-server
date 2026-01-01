import Foundation
@_implementationOnly import Vapor
import APIContract

// MARK: - RoutesBuilder Extension (Internal)

extension RoutesBuilder {
    /// APIグループをマウント（内部使用）
    @discardableResult
    func mount<Group: APIContractGroup, Handler: APIGroupHandler>(
        _ group: Group.Type,
        handler: Handler
    ) -> MountedGroup<Group, Handler> where Handler.Group == Group {
        let pathComponents = group.basePath.toPathComponents
        let routeGroup = self.grouped(pathComponents)
        return MountedGroup(routes: routeGroup, handler: handler)
    }

    /// 個別のエンドポイントを登録する（内部使用）
    @discardableResult
    func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, HandlerContext) async throws -> Endpoint.Output
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output: Encodable {
        let method = Vapor.HTTPMethod(rawValue: Endpoint.method.rawValue)
        let pathComponents = endpoint.subPath.toPathComponents

        self.on(method, pathComponents) { request async throws -> Response in
            // パスパラメータとクエリパラメータを収集
            let input = try request.decodeInput(Endpoint.self)

            // 認証コンテキストを構築
            let context = try request.buildHandlerContext(for: Endpoint.self)

            // ハンドラーを実行
            let output = try await handler(input, context)

            // レスポンスをエンコード
            return try request.encodeOutput(output)
        }

        return self
    }

    /// EmptyOutputを返すエンドポイントを登録する（内部使用）
    @discardableResult
    func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, HandlerContext) async throws -> Void
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output == EmptyOutput {
        let method = Vapor.HTTPMethod(rawValue: Endpoint.method.rawValue)
        let pathComponents = endpoint.subPath.toPathComponents

        self.on(method, pathComponents) { request async throws -> Response in
            let input = try request.decodeInput(Endpoint.self)
            let context = try request.buildHandlerContext(for: Endpoint.self)

            try await handler(input, context)

            return Response(status: .noContent)
        }

        return self
    }
}

// MARK: - Path Components Conversion

extension String {
    /// サブパスをVaporのPathComponentに変換（内部使用）
    var toPathComponents: [PathComponent] {
        guard !isEmpty else { return [] }

        return self.split(separator: "/").map { segment in
            let str = String(segment)
            if str.hasPrefix(":") {
                // パスパラメータ
                return PathComponent(stringLiteral: str)
            } else {
                return PathComponent(stringLiteral: str)
            }
        }
    }
}
