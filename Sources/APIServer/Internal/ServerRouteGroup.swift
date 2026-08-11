import Foundation
internal import Vapor
import APIContract


/// A path-prefixed group of routes, returned by `ServerApplication.group(_:)`.
///
/// Unlike `APIServerRouteGroup`, this group offers only GET and POST and cannot mount a
/// contract service; reach for `routes.group(_:)` when either is needed.
public struct ServerRouteGroup: @unchecked Sendable {
    let routes: RoutesBuilder

    /// Registers a GET route whose returned value is JSON-encoded and answered as `200 OK`.
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

    /// Registers a GET route whose handler receives the caller's identity, `.anonymous` when the
    /// request is unauthenticated.
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

    /// Registers a POST route whose handler receives the caller's identity, `.anonymous` when the
    /// request is unauthenticated.
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

    /// Creates a nested group, prefixed with this group's path and then the given one.
    public func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: routes.grouped(components))
    }
}

