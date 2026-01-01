import Foundation
@_implementationOnly import Vapor
import APIContract

/// Vaporベースのサーバーアプリケーション実装
public final class VaporServerApplication: ServerApplication, @unchecked Sendable {
    /// 内部Vaporアプリケーション
    let app: Application

    /// サーバー環境
    public let environment: ServerEnvironment

    /// ロガー
    public var logger: ServerLogger { VaporLogger(logger: app.logger) }

    /// ルート登録インターフェース
    public var routes: VaporRouteRegistrar { VaporRouteRegistrar(app: app) }

    /// 初期化
    public init(environment: ServerEnvironment = .detect()) async throws {
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

    /// ミドルウェアを追加（抽象化された ServerMiddleware）
    public func use(_ middleware: any ServerMiddleware) {
        app.middleware.use(VaporMiddlewareAdapter(middleware: middleware))
    }

    /// 認証ミドルウェアを追加
    ///
    /// - Parameter provider: 認証プロバイダー
    public func useAuth<P: AuthenticationProvider>(_ provider: P) {
        app.middleware.use(AuthMiddleware(provider: provider))
    }

    /// APIContractエラーミドルウェアを追加
    ///
    /// APIContractErrorをJSONエラーレスポンスに変換します。
    public func useErrorMiddleware() {
        app.middleware.use(APIContractErrorMiddleware())
    }

    /// サーバーを実行
    public func run() async throws {
        try await app.execute()
    }

    /// サーバーをシャットダウン
    public func shutdown() async throws {
        try await app.asyncShutdown()
    }

    deinit {
        Task { [app] in
            try? await app.asyncShutdown()
        }
    }

    // MARK: - Simple Route Registration

    /// シンプルなGETルートを登録（コンテキスト不要）
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try Self.encodeResponse(result)
        }
        return self
    }

    /// シンプルなPOSTルートを登録（コンテキスト不要）
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try Self.encodeResponse(result)
        }
        return self
    }

    // MARK: - Context-Aware Route Registration

    /// コンテキスト付きGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (HandlerContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.GET, components) { request async throws -> Vapor.Response in
            let context = Self.buildContext(from: request)
            let result = try await handler(context)
            return try Self.encodeResponse(result)
        }
        return self
    }

    /// コンテキスト付きPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (HandlerContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        app.on(.POST, components) { request async throws -> Vapor.Response in
            let context = Self.buildContext(from: request)
            let result = try await handler(context)
            return try Self.encodeResponse(result)
        }
        return self
    }

    // MARK: - Route Grouping

    /// ルートグループを作成
    public func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: app.grouped(components))
    }

    // MARK: - Private Helpers

    private static func encodeResponse<T: Encodable>(_ value: T) throws -> Vapor.Response {
        let data = try JSONEncoder.apiDefault.encode(value)
        var headers = HTTPHeaders()
        headers.contentType = .json
        return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
    }

    private static func buildContext(from request: Request) -> HandlerContext {
        if let userId = request.auth.get(AuthenticatedUser.self)?.id {
            return .authenticated(userId: userId)
        }
        return .anonymous
    }
}

// MARK: - Server Route Group

/// サーバールートグループ（Vapor非依存インターフェース）
public struct ServerRouteGroup: @unchecked Sendable {
    let routes: RoutesBuilder

    /// シンプルなGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeResponse(result)
        }
        return self
    }

    /// シンプルなPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { _ async throws -> Vapor.Response in
            let result = try await handler()
            return try encodeResponse(result)
        }
        return self
    }

    /// コンテキスト付きGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (HandlerContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.GET, components) { request async throws -> Vapor.Response in
            let context = buildContext(from: request)
            let result = try await handler(context)
            return try encodeResponse(result)
        }
        return self
    }

    /// コンテキスト付きPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (HandlerContext) async throws -> Response
    ) -> Self {
        let components = path.map { PathComponent(stringLiteral: $0) }
        routes.on(.POST, components) { request async throws -> Vapor.Response in
            let context = buildContext(from: request)
            let result = try await handler(context)
            return try encodeResponse(result)
        }
        return self
    }

    /// サブグループを作成
    public func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: routes.grouped(components))
    }

    private func encodeResponse<T: Encodable>(_ value: T) throws -> Vapor.Response {
        let data = try JSONEncoder.apiDefault.encode(value)
        var headers = HTTPHeaders()
        headers.contentType = .json
        return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
    }

    private func buildContext(from request: Request) -> HandlerContext {
        if let userId = request.auth.get(AuthenticatedUser.self)?.id {
            return .authenticated(userId: userId)
        }
        return .anonymous
    }
}

// MARK: - Vapor Logger Adapter

struct VaporLogger: ServerLogger {
    let logger: Logger

    func trace(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.trace("\(message())", file: file, function: function, line: line)
    }

    func debug(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.debug("\(message())", file: file, function: function, line: line)
    }

    func info(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.info("\(message())", file: file, function: function, line: line)
    }

    func notice(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.notice("\(message())", file: file, function: function, line: line)
    }

    func warning(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.warning("\(message())", file: file, function: function, line: line)
    }

    func error(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.error("\(message())", file: file, function: function, line: line)
    }

    func critical(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.critical("\(message())", file: file, function: function, line: line)
    }
}

// MARK: - Vapor Middleware Adapter

struct VaporMiddlewareAdapter: AsyncMiddleware {
    let middleware: any ServerMiddleware

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let serverRequest = VaporServerRequest(request: request)

        let serverResponse = try await middleware.handle(request: serverRequest) { _ in
            // 次のミドルウェア/ハンドラーを呼び出し
            let response = try await next.respond(to: request)
            return VaporServerResponse(response: response)
        }

        // ServerResponseをVapor Responseに変換
        if let vaporResponse = serverResponse as? VaporServerResponse {
            return vaporResponse.response
        }

        // BasicServerResponseなどの場合は変換
        var headers = HTTPHeaders()
        for (key, value) in serverResponse.headers {
            headers.add(name: key, value: value)
        }

        return Response(
            status: HTTPResponseStatus(statusCode: serverResponse.status.code),
            headers: headers,
            body: .init(data: serverResponse.body)
        )
    }
}

// MARK: - Vapor Request Adapter

struct VaporServerRequest: ServerRequest {
    let request: Request

    var pathParameters: [String: String] {
        // Vaporのパラメータは動的に取得する必要があるため、
        // 実際にはルート登録時に設定される
        [:]
    }

    var queryParameters: [String: String] {
        var params: [String: String] = [:]
        if let queryString = request.url.query {
            for item in queryString.split(separator: "&") {
                let parts = item.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                    let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    params[key] = value
                }
            }
        }
        return params
    }

    var headers: [String: String] {
        var result: [String: String] = [:]
        for (name, value) in request.headers {
            result[name] = value
        }
        return result
    }

    var body: Data? {
        guard let buffer = request.body.data else { return nil }
        return Data(buffer: buffer)
    }

    var url: URL {
        URL(string: request.url.string) ?? URL(string: "/")!
    }

    var method: String {
        request.method.rawValue
    }

    var authenticatedUserId: String? {
        request.auth.get(AuthenticatedUser.self)?.id
    }
}

// MARK: - Vapor Response Adapter

struct VaporServerResponse: ServerResponse {
    let response: Response

    var status: HTTPStatus {
        HTTPStatus(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase)
    }

    var headers: [String: String] {
        var result: [String: String] = [:]
        for (name, value) in response.headers {
            result[name] = value
        }
        return result
    }

    var body: Data {
        guard let buffer = response.body.buffer else { return Data() }
        return Data(buffer: buffer)
    }
}
