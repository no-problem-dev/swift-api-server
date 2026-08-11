import APIContract

/// Where routes are declared, whether at the root of a server or inside a group.
///
/// Every registration returns `Self`, so calls chain. Registering two handlers for the same method
/// and path is not rejected here — the first match wins at dispatch time.
public protocol Routes: Sendable {
    /// The type produced by `group(_:)`, itself a `Routes`.
    associatedtype Group: RouteGroup

    // MARK: - Simple Routes

    /// Registers a GET route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a POST route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a PUT route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func put<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a DELETE route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func delete<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// Registers a PATCH route whose returned value is JSON-encoded and answered as `200 OK`.
    @discardableResult
    func patch<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    // MARK: - Webhook Routes

    /// Registers a POST route that hands the handler the decoded body together with the request
    /// headers, and answers with the status the handler returns and an empty body.
    ///
    /// Bodies are decoded from `snake_case` keys, matching the convention of the event carriers
    /// this is meant for. An empty body is rejected with `400` before the handler runs.
    @discardableResult
    func webhook<Body: Decodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> HTTPStatus
    ) -> Self

    /// Registers a webhook route that answers `200 OK` with the handler's JSON-encoded value
    /// instead of a bare status.
    @discardableResult
    func webhook<Body: Decodable & Sendable, Response: Encodable & Sendable>(
        _ path: String...,
        body: Body.Type,
        handler: @escaping @Sendable (WebhookRequest<Body>) async throws -> Response
    ) -> Self

    /// Registers a webhook route that hands the handler the body bytes as sent.
    ///
    /// Nothing is parsed and `Content-Type` is ignored, which is what makes Protobuf and
    /// signature-verified payloads possible — verify a signature over these exact bytes.
    @discardableResult
    func webhookRaw(
        _ path: String...,
        handler: @escaping @Sendable (RawWebhookRequest) async throws -> HTTPStatus
    ) -> Self

    // MARK: - Grouping

    /// Creates a group that prefixes every route registered on it with the given path.
    func group(_ path: String...) -> Group

    // MARK: - APIContract Mounting

    /// Mounts a service under its contract group's base path, ready for endpoint registration.
    ///
    /// Mounting alone serves nothing; the endpoints still have to be registered on the result.
    func mount<S: APIService>(
        _ service: S
    ) -> APIRoutes<S.Group, S>
}

/// A `Routes` scoped under a path prefix, which can be nested further.
public protocol RouteGroup: Routes {}
