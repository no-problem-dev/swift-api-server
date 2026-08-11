import APIContract
import Foundation
internal import Vapor

// MARK: - SSE Route Extensions for VaporServerApplication

extension VaporServerApplication {
    /// Registers a GET route that streams Server-Sent Events.
    ///
    /// The response opens with a comment line as soon as the handler returns, so the client sees
    /// the connection established without waiting for a first event. Events are then written in
    /// the order the sequence yields them, and the response ends when the sequence finishes.
    ///
    /// If the sequence throws, the error is logged and the connection is closed normally — the
    /// client sees a clean end of stream, not an error, and will reconnect. Send a terminal event
    /// of your own if the client needs to distinguish the two.
    ///
    /// ## Example
    /// ```swift
    /// server.sse("events") {
    ///     AsyncStream { continuation in
    ///         continuation.yield(SSEEvent(data: "Hello"))
    ///         continuation.finish()
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the events to stream. It runs before the response is sent, so
    ///     throwing from it yields an ordinary error response rather than a broken stream.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a GET route that streams Server-Sent Events, with the caller's identity.
    ///
    /// The context is `.anonymous` unless the authentication middleware verified a token. Nothing
    /// enforces authentication for you — reject in the handler, as below.
    ///
    /// ## Example
    /// ```swift
    /// server.sse("user", "events") { context in
    ///     guard case .authenticated(let userId) = context else {
    ///         throw HTTPError.unauthorized
    ///     }
    ///     return userEventStream(for: userId)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Receives the caller's context and produces the events to stream.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events.
    ///
    /// POST is the usual choice when starting a stream requires parameters too large for a query
    /// string. The handler here does not receive the body — use the `body:` overload for that.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Produces the events to stream.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events, with the caller's identity.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Receives the caller's context and produces the events to stream.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events from a decoded request body.
    ///
    /// The body is decoded with ISO 8601 dates and key names taken as written. A body that fails
    /// to decode is rejected before the handler runs, so the client gets an error response rather
    /// than an empty stream.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - body: The type to decode the request body into.
    ///   - handler: Receives the caller's context and the decoded body, and produces the events
    ///     to stream.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (ServiceContext, Body) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let decodedBody = try VaporSSEBuilder.decodeBody(body, from: request)
            let stream = try await handler(context, decodedBody)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }
}

// MARK: - SSE Route Extensions for APIServerRouteGroup

extension APIServerRouteGroup {
    /// Registers a GET route that streams Server-Sent Events, scoped to this group's path.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a GET route that streams Server-Sent Events, with the caller's identity.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events, scoped to this group's path.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events, with the caller's identity.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events from a decoded request body.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (ServiceContext, Body) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let decodedBody = try VaporSSEBuilder.decodeBody(body, from: request)
            let stream = try await handler(context, decodedBody)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }
}

// MARK: - SSE Route Extensions for ServerRouteGroup

extension ServerRouteGroup {
    /// Registers a GET route that streams Server-Sent Events, scoped to this group's path.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a GET route that streams Server-Sent Events, with the caller's identity.
    @discardableResult
    public func sse<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events, scoped to this group's path.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let stream = try await handler()
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events, with the caller's identity.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let stream = try await handler(context)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }

    /// Registers a POST route that streams Server-Sent Events from a decoded request body.
    @discardableResult
    public func ssePost<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (ServiceContext, Body) async throws -> S
    ) -> Self where S.Element == SSEEvent {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Response in
            let context = VaporSSEBuilder.buildContext(from: request)
            let decodedBody = try VaporSSEBuilder.decodeBody(body, from: request)
            let stream = try await handler(context, decodedBody)
            return VaporSSEBuilder.buildSSEResponse(from: stream, request: request)
        }
        return self
    }
}
