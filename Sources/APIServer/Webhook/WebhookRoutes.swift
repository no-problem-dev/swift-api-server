import Foundation
internal import Vapor

// MARK: - Webhook Request

/// Webhook リクエストコンテキスト
///
/// Webhook エンドポイントで使用するリクエスト情報をカプセル化します。
/// ボディとヘッダーの両方にアクセスできます。
public struct WebhookRequest<Body: Decodable & Sendable>: Sendable {
    /// デコードされたリクエストボディ
    public let body: Body

    /// HTTPヘッダー
    public let headers: WebhookHeaders

    init(body: Body, headers: WebhookHeaders) {
        self.body = body
        self.headers = headers
    }
}

/// Webhook ヘッダー
///
/// HTTPヘッダーへの読み取りアクセスを提供します。
public struct WebhookHeaders: Sendable {
    private let storage: [String: String]

    init(from vaporHeaders: HTTPHeaders) {
        var dict: [String: String] = [:]
        for (name, value) in vaporHeaders {
            dict[name.lowercased()] = value
        }
        self.storage = dict
    }

    /// ヘッダー値を取得（大文字小文字を区別しない）
    public subscript(_ name: String) -> String? {
        storage[name.lowercased()]
    }

    /// ヘッダーが存在するかチェック
    public func contains(_ name: String) -> Bool {
        storage[name.lowercased()] != nil
    }

    /// 全ヘッダーを取得
    public var all: [String: String] {
        storage
    }
}

// MARK: - Webhook Route Extensions for VaporServerApplication

extension VaporServerApplication {
    /// Webhook POSTルートを登録
    ///
    /// リクエストボディとヘッダーの両方にアクセスできるエンドポイントを登録します。
    /// Eventarc や他のWebhookサービスからのイベント受信に使用します。
    ///
    /// ## 使用例
    /// ```swift
    /// server.webhook("webhooks", "auth", "user-created", body: AuthEvent.self) { request in
    ///     let event = request.body
    ///     let eventType = request.headers["ce-type"]
    ///     // イベント処理...
    ///     return .ok
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - body: デコードするボディの型
    ///   - handler: WebhookRequest を受け取り HTTPStatus を返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
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

    /// Webhook POSTルートを登録（レスポンスボディ付き）
    ///
    /// リクエストボディとヘッダーにアクセスし、レスポンスボディを返すエンドポイント。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - body: デコードするボディの型
    ///   - handler: WebhookRequest を受け取りレスポンスを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
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
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = Vapor.HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for VaporRoutes

extension VaporRoutes {
    /// Webhook POSTルートを登録
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

    /// Webhook POSTルートを登録（レスポンスボディ付き）
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
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = Vapor.HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for VaporRouteGroup

extension VaporRouteGroup {
    /// Webhook POSTルートを登録
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

    /// Webhook POSTルートを登録（レスポンスボディ付き）
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
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = Vapor.HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
        }
        return self
    }
}

// MARK: - Webhook Route Extensions for ServerRouteGroup

extension ServerRouteGroup {
    /// Webhook POSTルートを登録
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

    /// Webhook POSTルートを登録（レスポンスボディ付き）
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
            let data = try JSONEncoder.apiDefault.encode(result)
            var headers = Vapor.HTTPHeaders()
            headers.contentType = .json
            return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
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
}
