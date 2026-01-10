import Foundation
internal import Vapor
import APIContract

// MARK: - Request Decoding

extension Request {
    /// APIContractのInput型にリクエストをデコード
    ///
    /// パスパラメータ、クエリパラメータ、ボディを統合してInput型を構築します。
    func decodeInput<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type
    ) throws -> Endpoint.Input where Endpoint.Input == Endpoint, Endpoint: APIInput {
        // パスパラメータを収集（Vaporのパスパラメータを取得）
        var pathParams: [String: String] = [:]
        // Vaporはパスパラメータを `:name` 形式で登録し、`parameters.get("name")` で取得
        // pathTemplate（Group.basePath + subPath）からパスパラメータ名を抽出
        // これにより、ネストされたリソース（例: /v1/books/:bookId/chats）でも
        // basePath に定義されたパスパラメータを正しく抽出できる
        for segment in Endpoint.pathTemplate.split(separator: "/") {
            let str = String(segment)
            if str.hasPrefix(":") {
                let paramName = String(str.dropFirst())
                if let value = self.parameters.get(paramName) {
                    pathParams[paramName] = value
                }
            }
        }

        // クエリパラメータを収集
        var queryParams: [String: String] = [:]
        if let queryItems = self.url.query {
            for item in queryItems.split(separator: "&") {
                let parts = item.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                    let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    queryParams[key] = value
                }
            }
        }

        // ボディをデコード
        let bodyData: Data?
        if let body = self.body.data {
            bodyData = Data(buffer: body)
        } else {
            bodyData = nil
        }

        // APIInput.decode を使用してInput型を構築
        return try Endpoint.Input.decode(
            pathParameters: pathParams,
            queryParameters: queryParams,
            body: bodyData,
            decoder: JSONDecoder.apiDefault
        )
    }

    /// ServiceContextを構築
    ///
    /// リクエストの認証状態を確認し、適切なコンテキストを返します。
    func buildServiceContext<Endpoint: APIContract>(
        for endpoint: Endpoint.Type
    ) throws -> ServiceContext {
        let authRequirement = Endpoint.auth

        switch authRequirement {
        case .none:
            // 認証不要 - ユーザーIDがあれば使う
            if let userId = self.authenticatedUserId {
                return .authenticated(userId: userId)
            }
            return .anonymous

        case .required:
            // 必須認証 - ユーザーIDがなければエラー
            guard let userId = self.authenticatedUserId else {
                throw HTTPError.unauthorized
            }
            return .authenticated(userId: userId)
        }
    }

    /// 認証済みユーザーIDを取得
    ///
    /// 認証ミドルウェアによって設定されたユーザーIDを返します。
    /// ミドルウェアは `request.auth.login(user)` を使用してユーザーを設定する必要があります。
    var authenticatedUserId: String? {
        // Vapor標準のAuthenticatableを使用
        // FirebaseAuthServerのAuthenticatedUserなど
        self.auth.get(AuthenticatedUser.self)?.id
    }

    /// レスポンスをエンコード
    func encodeOutput<Output: Encodable & Sendable>(_ output: Output) throws -> Response {
        let encoder = JSONEncoder.apiDefault
        let data = try encoder.encode(output)

        var headers = HTTPHeaders()
        headers.contentType = .json

        return Response(
            status: .ok,
            headers: headers,
            body: .init(data: data)
        )
    }
}

// MARK: - Authenticated User

/// 認証済みユーザーを表す型（内部使用）
struct AuthenticatedUser: Authenticatable, Sendable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    /// API用のデフォルトJSONDecoder
    static var apiDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

