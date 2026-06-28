import Foundation
internal import Vapor
import APIContract

/// Vapor ベースの Routes 実装
public struct VaporRoutes: Routes, @unchecked Sendable {
    let routes: RoutesBuilder

    init(app: Application) {
        self.routes = app
    }

    init(routes: RoutesBuilder) {
        self.routes = routes
    }

    // MARK: - Simple Routes

    /// GET ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// POST ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// PUT ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PUT, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// DELETE ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.DELETE, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// PATCH ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PATCH, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    // MARK: - Grouping

    /// 共通パスプレフィックスを持つルートグループを作成する。
    ///
    /// - Parameter path: グループのパスプレフィックス（可変長）
    /// - Returns: `VaporRouteGroup`
    public func group(_ path: String...) -> VaporRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return VaporRouteGroup(routes: routes.grouped(components))
    }

    // MARK: - APIContract Mounting

    /// `APIService` をマウントし、サービス定義からルートを自動登録する。
    ///
    /// - Parameter service: マウントする APIService インスタンス
    /// - Returns: マウント結果の `APIRoutes`
    public func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S> {
        routes.mount(service)
    }
}

/// Vapor ベースの RouteGroup 実装
public struct VaporRouteGroup: RouteGroup, @unchecked Sendable {
    let routes: RoutesBuilder

    // MARK: - Simple Routes

    /// GET ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// POST ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// PUT ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PUT, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// DELETE ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.DELETE, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    /// PATCH ルートを登録する。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント（可変長）
    ///   - handler: レスポンスを返す非同期ハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PATCH, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }

    // MARK: - Grouping

    /// サブグループを作成する。
    ///
    /// - Parameter path: サブグループのパスプレフィックス（可変長）
    /// - Returns: `VaporRouteGroup`
    public func group(_ path: String...) -> VaporRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return VaporRouteGroup(routes: routes.grouped(components))
    }

    // MARK: - APIContract Mounting

    /// `APIService` をマウントし、サービス定義からルートを自動登録する。
    ///
    /// - Parameter service: マウントする APIService インスタンス
    /// - Returns: マウント結果の `APIRoutes`
    public func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S> {
        routes.mount(service)
    }
}
