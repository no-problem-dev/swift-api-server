import Foundation
internal import Vapor
import APIContract

/// The server implementation behind `Server.create()`.
///
/// Kept internal so the web framework it wraps never appears in the package's public API.
final class VaporServerApplication: ServerApplication, @unchecked Sendable {
    let app: Application

    let environment: ServerEnvironment

    var logger: ServerLogger { VaporLogger(logger: app.logger) }

    /// A fresh registrar each time; the routes it registers all land on the same application.
    var routes: APIServerRoutes { APIServerRoutes(app: app) }

    init(environment: ServerEnvironment = .detect()) async throws {
        let vaporEnv: Vapor.Environment
        switch environment {
        case .development:
            vaporEnv = .development
        case .testing:
            vaporEnv = .testing
        case .production:
            vaporEnv = .production
        }

        self.environment = environment
        self.app = try await Application.make(vaporEnv)
    }

    /// Appends a middleware, wrapped so the framework can drive it.
    func use(_ middleware: any ServerMiddleware) {
        app.middleware.use(VaporMiddlewareAdapter(middleware: middleware, logger: app.logger))
    }

    /// Installs Bearer-token authentication, which annotates requests but never rejects them.
    ///
    /// - Parameter provider: Verifies a token and returns the user ID it identifies.
    func useAuth<P: AuthenticationProvider>(_ provider: P) {
        app.middleware.use(AuthMiddleware(provider: provider))
    }

    /// Installs the middleware that turns thrown errors into JSON error responses.
    ///
    /// It only catches what is thrown after it, so register it before the routes it should cover.
    func useErrorMiddleware() {
        app.middleware.use(APIContractErrorMiddleware())
    }

    /// Sets the maximum accepted request body size.
    ///
    /// Applies to routes registered afterwards. The default is small — on the order of tens of
    /// kilobytes — so uploads need this raised.
    ///
    /// - Parameter bytes: The limit in bytes.
    func setMaxBodySize(_ bytes: Int) {
        app.routes.defaultMaxBodySize = ByteCount(value: bytes)
    }

    /// Sets the maximum accepted request body size from a size literal such as `"10mb"`.
    ///
    /// - Parameter size: A count with a unit suffix: `"500kb"`, `"10mb"`, `"1gb"`.
    func setMaxBodySize(_ size: String) {
        app.routes.defaultMaxBodySize = ByteCount(stringLiteral: size)
    }

    /// Starts serving and suspends until the server stops.
    func run() async throws {
        try await app.execute()
    }

    /// Stops the server and releases its event loops.
    func shutdown() async throws {
        try await app.asyncShutdown()
    }

    deinit {
        Task { [app] in
            try? await app.asyncShutdown()
        }
    }

    // MARK: - Simple Route Registration

    /// Registers a GET route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a POST route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeJSONResponse(result)
        }
        return self
    }

    // MARK: - Context-Aware Route Registration

    /// Registers a GET route whose handler receives the caller's identity, `.anonymous` when the
    /// request is unauthenticated.
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { request async throws -> Vapor.Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let result = try await handler(context)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a POST route whose handler receives the caller's identity, `.anonymous` when the
    /// request is unauthenticated.
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Vapor.Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let result = try await handler(context)
            return try encodeJSONResponse(result)
        }
        return self
    }

    // MARK: - Route Grouping

    /// Creates a group that prefixes every route registered on it with the given path.
    func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: app.grouped(components))
    }

    // MARK: - Private Helpers
}

