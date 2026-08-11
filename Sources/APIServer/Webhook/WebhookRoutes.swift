import Foundation
internal import Vapor

// MARK: - Webhook Request

/// A webhook delivery: the decoded body plus the headers it arrived with.
///
/// Headers matter here more than on an ordinary route — event carriers put the event type,
/// delivery ID and signature there rather than in the payload.
public struct WebhookRequest<Body: Decodable & Sendable>: Sendable {
    /// The body, decoded from JSON with `snake_case` keys converted to camel case.
    public let body: Body

    /// The headers the delivery arrived with.
    public let headers: WebhookHeaders

    init(body: Body, headers: WebhookHeaders) {
        self.body = body
        self.headers = headers
    }
}

/// A webhook delivery whose body is handed over exactly as it arrived.
///
/// For payloads that are not JSON, such as Protobuf, and for any payload whose signature must be
/// verified over the bytes the sender signed rather than a re-encoding of them.
public struct RawWebhookRequest: Sendable {
    /// The body bytes, unparsed. `Content-Type` is not consulted.
    public let data: Data

    /// The headers the delivery arrived with.
    public let headers: WebhookHeaders

    init(data: Data, headers: WebhookHeaders) {
        self.data = data
        self.headers = headers
    }
}

/// The headers of a webhook delivery, looked up without regard to case.
///
/// Names are lowercased on the way in, so `"CE-Type"` and `"ce-type"` find the same value. A
/// header sent more than once keeps only its last value.
public struct WebhookHeaders: Sendable {
    private let storage: [String: String]

    init(from vaporHeaders: HTTPHeaders) {
        var dict: [String: String] = [:]
        for (name, value) in vaporHeaders {
            dict[name.lowercased()] = value
        }
        self.storage = dict
    }

    /// Returns a header's value, or `nil` if it was not sent.
    ///
    /// - Parameter name: The header name, in any case.
    public subscript(_ name: String) -> String? {
        storage[name.lowercased()]
    }

    /// Reports whether a header was sent, regardless of its value.
    ///
    /// - Parameter name: The header name, in any case.
    public func contains(_ name: String) -> Bool {
        storage[name.lowercased()] != nil
    }

    /// Every header, keyed by lowercased name.
    public var all: [String: String] {
        storage
    }
}

// MARK: - Webhook Route Extensions for VaporServerApplication

extension VaporServerApplication {
    /// Registers a POST route for webhook deliveries, answering with a bare status.
    ///
    /// The body is decoded as JSON with `snake_case` keys converted to camel case — the convention
    /// most event carriers use, and deliberately different from the ISO 8601, verbatim-key decoding
    /// applied to contract endpoints. A delivery with an empty body is rejected with `400` before
    /// the handler runs.
    ///
    /// The response carries the returned status and no body, so senders that retry on non-2xx can
    /// be told to stop by returning `.ok` even when the event was ignored.
    ///
    /// ## Example
    /// ```swift
    /// server.webhook("webhooks", "auth", "user-created", body: AuthEvent.self) { request in
    ///     let event = request.body
    ///     let eventType = request.headers["ce-type"]
    ///     // Handle the event…
    ///     return .ok
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - body: The type to decode the delivery into.
    ///   - handler: Handles the delivery and returns the status to answer with.
    @discardableResult
    public func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }

    /// Registers a webhook route that answers `200 OK` with a JSON body.
    ///
    /// For senders that expect a payload back, such as a challenge response during endpoint
    /// verification. The status is always `200`; return a status from the other overload instead
    /// when it needs to vary.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - body: The type to decode the delivery into.
    ///   - handler: Handles the delivery and returns the value to encode as the response.
    @discardableResult
    public func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let result = try await handler(webhookRequest)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a webhook route that hands the handler the body bytes as sent.
    ///
    /// Nothing is parsed and `Content-Type` is ignored, which is what makes Protobuf payloads and
    /// signature verification possible — verify the signature over these exact bytes. An empty
    /// body is still rejected with `400`.
    ///
    /// - Parameters:
    ///   - path: The path components to serve.
    ///   - handler: Handles the delivery and returns the status to answer with.
    @discardableResult
    public func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRawRequest(from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for APIServerRoutes

extension APIServerRoutes {
    /// Registers a POST route for webhook deliveries, answering with a bare status.
    @discardableResult
    public func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }

    /// Registers a webhook route that answers `200 OK` with a JSON body.
    @discardableResult
    public func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let result = try await handler(webhookRequest)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a webhook route that hands the handler the body bytes as sent.
    @discardableResult
    public func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRawRequest(from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for APIServerRouteGroup

extension APIServerRouteGroup {
    /// Registers a POST route for webhook deliveries, answering with a bare status.
    @discardableResult
    public func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }

    /// Registers a webhook route that answers `200 OK` with a JSON body.
    @discardableResult
    public func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let result = try await handler(webhookRequest)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a webhook route that hands the handler the body bytes as sent.
    @discardableResult
    public func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRawRequest(from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for ServerRouteGroup

extension ServerRouteGroup {
    /// Registers a POST route for webhook deliveries, answering with a bare status.
    @discardableResult
    public func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }

    /// Registers a webhook route that answers `200 OK` with a JSON body.
    @discardableResult
    public func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRequest(body, from: request)
            let result = try await handler(webhookRequest)
            return try encodeJSONResponse(result)
        }
        return self
    }

    /// Registers a webhook route that hands the handler the body bytes as sent.
    @discardableResult
    public func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let webhookRequest = try WebhookBuilder.buildRawRequest(from: request)
            let status = try await handler(webhookRequest)
            return Vapor.Response(status: .init(statusCode: status.code))
        }
        return self
    }
}

// MARK: - Webhook Builder

enum WebhookBuilder {
    static func buildRequest<Body: Decodable>(
        _ bodyType: Body.Type,
        from request: Request
    ) throws -> WebhookRequest<Body> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let buffer = request.body.data else {
            throw Abort(.badRequest, reason: "Request body is empty")
        }

        let body = try decoder.decode(bodyType, from: buffer)
        let headers = WebhookHeaders(from: request.headers)

        return WebhookRequest(body: body, headers: headers)
    }

    static func buildRawRequest(from request: Request) throws -> RawWebhookRequest {
        guard let buffer = request.body.data else {
            throw Abort(.badRequest, reason: "Request body is empty")
        }

        let data = Data(buffer: buffer)
        let headers = WebhookHeaders(from: request.headers)

        return RawWebhookRequest(data: data, headers: headers)
    }
}
