import APIContract

/// サーバーアプリケーションプロトコル
///
/// HTTP サーバーの抽象インターフェース。
/// アプリケーション層はこのプロトコルを通じてサーバー機能にアクセスし、
/// 具体的なフレームワーク（Vapor 等）の実装詳細から分離される。
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

    /// 認証ミドルウェアを追加
    func useAuth<P: AuthenticationProvider>(_ provider: P)

    /// APIContract エラーミドルウェアを追加
    func useErrorMiddleware()

    /// 最大リクエストボディサイズを設定する（バイト数指定）
    func setMaxBodySize(_ bytes: Int)

    /// 最大リクエストボディサイズを設定する（`"10mb"` 等の文字列指定）
    func setMaxBodySize(_ size: String)

    /// シンプルな GET ルートを登録（コンテキスト不要）
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// コンテキスト付き GET ルートを登録
    @discardableResult
    func get<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self

    /// シンプルな POST ルートを登録（コンテキスト不要）
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable () async throws -> Response
    ) -> Self

    /// コンテキスト付き POST ルートを登録
    @discardableResult
    func post<Response: Encodable & Sendable>(
        _ path: String...,
        handler: @escaping @Sendable (ServiceContext) async throws -> Response
    ) -> Self

    /// ルートグループを作成
    func group(_ path: String...) -> ServerRouteGroup

    /// サーバーを実行
    func run() async throws

    /// サーバーをシャットダウン
    func shutdown() async throws
}

// MARK: - Server Factory

/// サーバーファクトリ
///
/// サーバーアプリケーションを生成するファクトリ型。
/// 内部的に Vapor を使用するが、アプリケーション層からは隠蔽される。
///
/// ## 使用例
/// ```swift
/// let server = try await Server.create()
/// server.use(CORSServerMiddleware())
/// server.get("health") { "OK" }
/// try await server.run()
/// ```
public enum Server {
    /// サーバーアプリケーションを生成
    ///
    /// 戻り値は不透明型なので、呼び出し側から具象実装（およびそれが依存する
    /// Web フレームワーク）は見えない。`any ServerApplication` ではなく
    /// `some ServerApplication` にしているのは、`associatedtype Routes` を
    /// 保つため — existential にすると `server.routes` が取り出せなくなる。
    ///
    /// - Parameter environment: サーバー環境（デフォルトは自動検出）
    /// - Returns: サーバーアプリケーション
    public static func create(
        environment: ServerEnvironment = .detect()
    ) async throws -> some ServerApplication {
        try await VaporServerApplication(environment: environment)
    }
}
