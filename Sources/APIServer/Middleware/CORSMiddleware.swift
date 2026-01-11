import APIContract

/// CORS（Cross-Origin Resource Sharing）ミドルウェア
///
/// クロスオリジンリクエストを許可するためのミドルウェア。
/// DataResponse/StreamResponse どちらにも対応。
public struct CORSServerMiddleware: ServerMiddleware {
    private let configuration: CORSConfiguration

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

/// CORS設定
public struct CORSConfiguration: Sendable {
    /// 許可するオリジン
    public let allowedOrigins: [String]

    /// 許可するHTTPメソッド
    public let allowedMethods: [APIMethod]

    /// 許可するHTTPヘッダー
    public let allowedHeaders: [String]

    /// 公開するレスポンスヘッダー
    public let exposedHeaders: [String]

    /// 認証情報を許可するか
    public let allowCredentials: Bool

    /// プリフライトキャッシュ時間（秒）
    public let maxAge: Int?

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

    /// カスタム設定
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
