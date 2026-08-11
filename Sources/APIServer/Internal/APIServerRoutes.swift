import Foundation
internal import Vapor
import APIContract

/// The route registrar handed out by a server, backed by the underlying web framework.
public struct APIServerRoutes: Routes, @unchecked Sendable {
    let routes: RoutesBuilder

    init(app: Application) {
        self.routes = app
    }

    init(routes: RoutesBuilder) {
        self.routes = routes
    }

    // MARK: - Simple Routes

    /// Registers a GET route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
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

    /// Registers a POST route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
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

    /// Registers a PUT route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PUT, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a DELETE route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.DELETE, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a PATCH route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PATCH, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    // MARK: - Grouping

    /// Creates a group that prefixes every route registered on it with the given path.
    ///
    /// - Parameter path: The path components to prefix with.
    public func group(_ path: String...) -> APIServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return APIServerRouteGroup(routes: routes.grouped(components))
    }

    // MARK: - APIContract Mounting

    /// Mounts a service under its contract group's base path.
    ///
    /// Mounting alone serves nothing — register the endpoints on the result, usually in one call
    /// through the group's generated `registerAll`.
    ///
    /// - Parameter service: The service to mount.
    public func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S> {
        routes.mount(service)
    }
}

/// A route registrar scoped under a path prefix, produced by `group(_:)`.
public struct APIServerRouteGroup: RouteGroup, @unchecked Sendable {
    let routes: RoutesBuilder

    // MARK: - Simple Routes

    /// Registers a GET route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
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

    /// Registers a POST route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
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

    /// Registers a PUT route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PUT, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a DELETE route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.DELETE, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a PATCH route whose returned value is JSON-encoded and answered as `200 OK`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the value to encode.
    @discardableResult
    public func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.PATCH, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    // MARK: - Grouping

    /// Creates a nested group, prefixed with this group's path and then the given one.
    ///
    /// - Parameter path: The path components to prefix with.
    public func group(_ path: String...) -> APIServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return APIServerRouteGroup(routes: routes.grouped(components))
    }

    // MARK: - APIContract Mounting

    /// Mounts a service under its contract group's base path.
    ///
    /// Mounting alone serves nothing — register the endpoints on the result, usually in one call
    /// through the group's generated `registerAll`.
    ///
    /// - Parameter service: The service to mount.
    public func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S> {
        routes.mount(service)
    }
}
