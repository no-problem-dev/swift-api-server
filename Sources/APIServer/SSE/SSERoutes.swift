import Foundation
internal import Vapor

// MARK: - SSE Route Extensions for VaporServerApplication

extension VaporServerApplication {
    /// SSEストリームルートを登録（コンテキスト不要）
    ///
    /// AsyncSequenceからSSEイベントをストリーミングするエンドポイントを登録します。
    ///
    /// ## 使用例
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
    ///   - path: パスコンポーネント
    ///   - handler: SSEイベントのAsyncSequenceを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
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

    /// SSEストリームルートを登録（コンテキスト付き）
    ///
    /// ServiceContextを受け取るバージョン。認証情報などにアクセスできます。
    ///
    /// ## 使用例
    /// ```swift
    /// server.sse("user", "events") { context in
    ///     guard case .authenticated(let userId) = context else {
    ///         throw APIError.unauthorized
    ///     }
    ///     return userEventStream(for: userId)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - handler: ServiceContextとSSEイベントのAsyncSequenceを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト不要）
    ///
    /// リクエストボディを受け取ってSSEストリームを返すエンドポイント用。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - handler: SSEイベントのAsyncSequenceを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト付き）
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - handler: ServiceContextとSSEイベントのAsyncSequenceを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト + ボディ付き）
    ///
    /// リクエストボディをデコードしてSSEストリームを返すエンドポイント用。
    ///
    /// - Parameters:
    ///   - path: パスコンポーネント
    ///   - body: デコードするボディの型
    ///   - handler: ServiceContext、ボディ、SSEイベントのAsyncSequenceを返すハンドラー
    /// - Returns: Self（メソッドチェーン用）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
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

// MARK: - SSE Route Extensions for VaporRouteGroup

extension VaporRouteGroup {
    /// SSEストリームルートを登録（コンテキスト不要）
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

    /// SSEストリームルートを登録（コンテキスト付き）
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト不要）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト付き）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト + ボディ付き）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
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
    /// SSEストリームルートを登録（コンテキスト不要）
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

    /// SSEストリームルートを登録（コンテキスト付き）
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト不要）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト付き）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable>(
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

    /// POSTでSSEストリームを開始するルートを登録（コンテキスト + ボディ付き）
    @discardableResult
    public func postSSE<S: AsyncSequence & Sendable, Body: Decodable & Sendable>(
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
