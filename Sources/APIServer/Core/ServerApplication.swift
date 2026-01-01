import APIContract

/// サーバーアプリケーションプロトコル
///
/// HTTPサーバーの抽象インターフェース。
/// アプリケーション層はこのプロトコルを通じてサーバー機能にアクセスし、
/// 具体的なフレームワーク（Vapor等）の詳細から分離されます。
public protocol ServerApplication: Sendable {
    /// ルート登録インターフェース
    associatedtype Routes: APIServer.Routes

    /// サーバー環境
    var environment: ServerEnvironment { get }

    /// ロガー
    var logger: ServerLogger { get }

    /// ルート登録用インターフェース
    var routes: Routes { get }

    /// ミドルウェアを追加
    func use(_ middleware: any ServerMiddleware)

    /// サーバーを実行
    func run() async throws

    /// サーバーをシャットダウン
    func shutdown() async throws
}

// MARK: - Server Factory

/// サーバーファクトリ
///
/// サーバーアプリケーションを生成するためのファクトリクラス。
/// 内部的にVaporを使用しますが、アプリケーション層からは隠蔽されます。
///
/// ## 使用例
/// ```swift
/// let server = try await Server.create()
/// server.use(CORSMiddleware())
/// server.routes.get("health") { "OK" }
/// try await server.run()
/// ```
public enum Server {
    /// サーバーアプリケーションを生成
    ///
    /// - Parameter environment: サーバー環境（デフォルトは自動検出）
    /// - Returns: サーバーアプリケーション
    public static func create(
        environment: ServerEnvironment = .detect()
    ) async throws -> VaporServerApplication {
        try await VaporServerApplication(environment: environment)
    }
}
