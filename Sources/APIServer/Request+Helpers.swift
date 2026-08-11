import Foundation
internal import Vapor
import APIContract

// MARK: - Request Decoding

extension Request {
    /// Builds an endpoint's input from the path, the query string and the body.
    ///
    /// Dates in the body are decoded as ISO 8601. Query values are percent-decoded but `+` is not
    /// treated as a space, and a repeated key keeps only its last occurrence.
    func decodeInput<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type
    ) throws -> Endpoint.Input where Endpoint.Input == Endpoint, Endpoint: APIInput {
        var pathParams: [String: String] = [:]
        // Parameter names are read from the endpoint's full path template — the group's base path
        // plus the sub-path — not just the sub-path. That is what lets a nested resource such as
        // `/v1/books/:bookId/chats` see `bookId`, which is declared on the base path.
        for segment in Endpoint.pathTemplate.split(separator: "/") {
            let str = String(segment)
            if str.hasPrefix(":") {
                let paramName = String(str.dropFirst())
                if let value = self.parameters.get(paramName) {
                    pathParams[paramName] = value
                }
            }
        }

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

        let bodyData: Data?
        if let body = self.body.data {
            bodyData = Data(buffer: body)
        } else {
            bodyData = nil
        }

        return try Endpoint.Input.decode(
            pathParameters: pathParams,
            queryParameters: queryParams,
            body: bodyData,
            decoder: JSONDecoder.apiDefault
        )
    }

    /// Derives the handler's context from the endpoint's authentication requirement.
    ///
    /// `.none` passes the identity through when one is present and yields `.anonymous` otherwise.
    /// Every other requirement demands an identity and throws `HTTPError.unauthorized` without it.
    ///
    /// All three demanding cases are treated identically: whichever credential the endpoint
    /// nominates, the identity can only have been established by the Bearer-token middleware,
    /// which is the sole authenticator shipped here.
    ///
    /// - Throws: `HTTPError.unauthorized` when the endpoint requires authentication and the
    ///   request carries no verified identity.
    func buildServiceContext<Endpoint: APIContract>(
        for endpoint: Endpoint.Type
    ) throws -> ServiceContext {
        let authRequirement = Endpoint.auth

        switch authRequirement {
        case .none:
            if let userId = self.authenticatedUserId {
                return .authenticated(userId: userId)
            }
            return .anonymous

        case .bearer, .apiKey, .queryParam:
            guard let userId = self.authenticatedUserId else {
                throw HTTPError.unauthorized
            }
            return .authenticated(userId: userId)
        }
    }

    /// The identity established earlier in the middleware chain, or `nil` if the request is
    /// unauthenticated.
    var authenticatedUserId: String? {
        self.auth.get(AuthenticatedUser.self)?.id
    }

    /// Encodes a handler's return value as a `200 OK` JSON response.
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

/// The verified identity stored on a request, carrying only the user ID the provider returned.
struct AuthenticatedUser: Authenticatable, Sendable {
    let id: String

    init(id: String) {
        self.id = id
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    /// A decoder that reads dates as ISO 8601 and leaves key names untouched.
    ///
    /// Contract endpoints decode their bodies with this. Webhook routes deliberately do not —
    /// they convert keys from `snake_case` instead.
    static var apiDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

