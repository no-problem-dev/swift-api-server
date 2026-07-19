import Foundation
internal import Vapor
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
    public var routes: APIServerRoutes { APIServerRoutes(app: app) }

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
        app.middleware.use(VaporMiddlewareAdapter(middleware: middleware, logger: app.logger))
    }

    /// 認証ミドルウェアを追加
    ///
    /// - Parameter provider: 認証プロバイダー
    public func useAuth<P: AuthenticationProvider>(_ provider: P) {
        app.middleware.use(AuthMiddleware(provider: provider))
    }

    /// APIContractエラーミドルウェアを追加
    ///
    /// APIContractError を JSON エラーレスポンスに変換する。
    public func useErrorMiddleware() {
        app.middleware.use(APIContractErrorMiddleware())
    }

    /// 最大リクエストボディサイズを設定する。
    ///
    /// デフォルトは 16 KB。大きなファイルアップロードを受け付ける場合は増やす。
    /// - Parameter bytes: 最大バイト数
    public func setMaxBodySize(_ bytes: Int) {
        app.routes.defaultMaxBodySize = ByteCount(value: bytes)
    }

    /// 最大リクエストボディサイズを設定（文字列指定）
    ///
    /// 例: "10mb", "500kb", "1gb"
    /// - Parameter size: サイズ文字列
    public func setMaxBodySize(_ size: String) {
        app.routes.defaultMaxBodySize = ByteCount(stringLiteral: size)
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
            return try encodeJSONResponse(result)
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
            return try encodeJSONResponse(result)
        }
        return self
    }

    // MARK: - Context-Aware Route Registration

    /// コンテキスト付きGETルートを登録
    @discardableResult
    public func get<Response: Encodable & Sendable>(
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

    /// コンテキスト付きPOSTルートを登録
    @discardableResult
    public func post<Response: Encodable & Sendable>(
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

    /// ルートグループを作成
    public func group(_ path: String...) -> ServerRouteGroup {
        let components = path.map { PathComponent(stringLiteral: $0) }
        return ServerRouteGroup(routes: app.grouped(components))
    }

    // MARK: - Private Helpers
}

