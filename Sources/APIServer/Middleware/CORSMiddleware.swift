import APIContract

/// CORS（Cross-Origin Resource Sharing）ミドルウェア
///
/// クロスオリジンリクエストを許可するミドルウェア。
/// `DataResponse`・`StreamResponse` どちらにも対応する。
/// `server.use(CORSServerMiddleware())` で追加する。
public struct CORSServerMiddleware: ServerMiddleware {
    private let configuration: CORSConfiguration

    /// CORS ミドルウェアを作成する。
    ///
    /// - Parameter configuration: CORS 設定（省略時はデフォルト設定）
    public init(configuration: CORSConfiguration = .default()) {
        self.configuration = configuration
    }

    public func handle(
        request: any ServerRequest,
        next: @escaping @Sendable (any ServerRequest) async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        // プリフライトリクエストの処理
        if request.method == "OPTIONS" {
            return BasicDataResponse(
                status: .noContent,
                headers: corsHeaders(for: request)
            )
        }

        // 通常のリクエスト処理
        let response = try await next(request)

        // CORSヘッダーを追加
        return response.addingHeaders(corsHeaders(for: request))
    }

    private func corsHeaders(for request: any ServerRequest) -> [String: String] {
        var headers: [String: String] = [:]

        // Origin
        if let origin = request.headers["Origin"] {
            if configuration.allowedOrigins.contains("*") ||
               configuration.allowedOrigins.contains(origin) {
                headers["Access-Control-Allow-Origin"] = origin
            }
        } else if configuration.allowedOrigins.contains("*") {
            headers["Access-Control-Allow-Origin"] = "*"
        }

        // Methods
        headers["Access-Control-Allow-Methods"] = configuration.allowedMethods
            .map { $0.rawValue }
            .joined(separator: ", ")

        // Headers
        if !configuration.allowedHeaders.isEmpty {
            headers["Access-Control-Allow-Headers"] = configuration.allowedHeaders.joined(separator: ", ")
        }

        // Credentials
        if configuration.allowCredentials {
            headers["Access-Control-Allow-Credentials"] = "true"
        }

        // Max Age
        if let maxAge = configuration.maxAge {
            headers["Access-Control-Max-Age"] = String(maxAge)
        }

        // Exposed Headers
        if !configuration.exposedHeaders.isEmpty {
            headers["Access-Control-Expose-Headers"] = configuration.exposedHeaders.joined(separator: ", ")
        }

        return headers
    }
}

/// CORS 設定
///
/// `CORSServerMiddleware` に渡す設定値をまとめた型。
/// `default()` または `custom(allowedOrigins:...)` ファクトリを使うのが簡便。
public struct CORSConfiguration: Sendable {
    /// 許可するオリジン
    public let allowedOrigins: [String]

    /// 許可する HTTP メソッド
    public let allowedMethods: [APIMethod]

    /// 許可する HTTP ヘッダー
    public let allowedHeaders: [String]

    /// クライアントへ公開するレスポンスヘッダー
    public let exposedHeaders: [String]

    /// 認証情報（Cookie / 認証ヘッダー）を許可するか
    public let allowCredentials: Bool

    /// プリフライトレスポンスのキャッシュ時間（秒）。`nil` で無効
    public let maxAge: Int?

    /// CORS 設定を作成する。
    ///
    /// - Parameters:
    ///   - allowedOrigins: 許可するオリジン（`["*"]` で全許可）
    ///   - allowedMethods: 許可する HTTP メソッド
    ///   - allowedHeaders: 許可するリクエストヘッダー
    ///   - exposedHeaders: クライアントへ公開するレスポンスヘッダー
    ///   - allowCredentials: 認証情報を許可するか
    ///   - maxAge: プリフライトキャッシュ時間（秒、`nil` で無効）
    public init(
        allowedOrigins: [String] = ["*"],
        allowedMethods: [APIMethod] = [.get, .post, .put, .patch, .delete, .options],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"],
        exposedHeaders: [String] = [],
        allowCredentials: Bool = false,
        maxAge: Int? = 600
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.allowCredentials = allowCredentials
        self.maxAge = maxAge
    }

    /// デフォルト設定
    public static func `default`() -> CORSConfiguration {
        CORSConfiguration()
    }

    /// カスタム CORS 設定を作成する。
    ///
    /// よく使うパラメータに絞ったファクトリ。`exposedHeaders`/`maxAge` が不要な場合に簡便。
    ///
    /// - Parameters:
    ///   - allowedOrigins: 許可するオリジン（例: `["https://example.com"]`、`["*"]` で全許可）
    ///   - allowedMethods: 許可する HTTP メソッド
    ///   - allowedHeaders: 許可するリクエストヘッダー
    ///   - allowCredentials: Cookie や `Authorization` ヘッダーなどの認証情報をクロスオリジンで許可するか。
    ///     `true` にする場合、`allowedOrigins` に `"*"` を指定できない（セキュリティ制約）。
    /// - Returns: `CORSConfiguration`
    public static func custom(
        allowedOrigins: [String],
        allowedMethods: [APIMethod] = [.get, .post, .put, .patch, .delete, .options],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"],
        allowCredentials: Bool = false
    ) -> CORSConfiguration {
        CORSConfiguration(
            allowedOrigins: allowedOrigins,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            allowCredentials: allowCredentials
        )
    }
}
