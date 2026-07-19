import Foundation
internal import Vapor
import APIContract


/// サーバールートグループ（Vapor非依存インターフェース）
public struct ServerRouteGroup: @unchecked Sendable {
    let routes: RoutesBuilder

    /// シンプルなGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// シンプルなPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// コンテキスト付きGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Vapor.Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let result = try await handler(context)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// コンテキスト付きPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let result = try await handler(context)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// サブグループを作成
    public func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: routes.grouped(components))
    }
}

