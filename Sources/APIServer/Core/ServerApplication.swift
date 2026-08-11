import APIContract

/// The HTTP server seen by application code, with no web-framework types in its signatures.
///
/// Obtain one from `Server.create()`. The only conformer shipped here is backed by Vapor and is
/// internal, so application code can be compiled and tested against this protocol alone.
///
/// Middleware runs in registration order, and the error middleware only catches what is thrown
/// *after* it, so register it before the handlers whose errors it should convert.
public protocol ServerApplication: Sendable {
    /// The route registrar this application exposes, kept as an associated type so callers keep
    /// access to its own associated types.
    associatedtype Routes: APIServer.Routes

    /// The environment the server was created for.
    var environment: ServerEnvironment { get }

    /// The log sink shared with the underlying server.
    var logger: ServerLogger { get }

    /// The entry point for registering routes and mounting services.
    var routes: Routes { get }

    /// Appends a middleware to the chain.
    ///
    /// Order matters: middleware added first sees the request first and the response last.
    func use(_ middleware: any ServerMiddleware)

    /// Installs Bearer-token authentication backed by the given provider.
    ///
    /// The middleware never rejects a request on its own — a missing or invalid token simply
    /// leaves the request unauthenticated, and per-endpoint `auth` requirements decide the outcome.
    func useAuth<P: AuthenticationProvider>(_ provider: P)

    /// Installs the middleware that turns thrown errors into JSON error responses.
    func useErrorMiddleware()

    /// Sets the maximum accepted request body size in bytes.
    func setMaxBodySize(_ bytes: Int)

    /// Sets the maximum accepted request body size from a size literal such as `"10mb"`.
    func setMaxBodySize(_ size: String)

    /// Registers a GET route whose handler needs no request context.
    ///
    /// The returned value is JSON-encoded with ISO 8601 dates and answered as `200 OK`.
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a GET route whose handler receives the caller's authentication context.
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self

    /// Registers a POST route whose handler needs no request context.
    ///
    /// The returned value is JSON-encoded with ISO 8601 dates and answered as `200 OK`.
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a POST route whose handler receives the caller's authentication context.
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self

    /// Creates a group that prefixes every route registered on it with the given path.
    func group(_ path: String...) -> ServerRouteGroup

    /// Starts serving and suspends until the server stops.
    func run() async throws

    /// Stops the server and releases its event loops.
    func shutdown() async throws
}

// MARK: - Server Factory

/// The entry point that builds a server without naming its implementation.
///
/// ## Example
/// ```swift
/// let server = try await Server.create()
/// server.use(CORSServerMiddleware())
/// server.get("health") { "OK" }
/// try await server.run()
/// ```
public enum Server {
    /// Creates a running-ready server for the given environment.
    ///
    /// The result is an opaque type, so neither the concrete implementation nor the web framework
    /// it depends on is visible to callers. It is `some ServerApplication` rather than
    /// `any ServerApplication` in order to preserve the associated `Routes` type — an existential
    /// would make `server.routes` unusable.
    ///
    /// - Parameter environment: The environment to run in; detected from the process environment
    ///   by default.
    /// - Returns: A server that has no middleware or routes registered yet.
    public static func create(
        environment: ServerEnvironment = .detect()
    ) async throws -> some ServerApplication {
        try await VaporServerApplication(environment: environment)
    }
}
