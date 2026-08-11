import XCTest
import XCTVapor
import APIContract
@testable import APIServer

final class AuthMiddlewareTests: XCTestCase {

    // MARK: - Test AuthenticationProvider

    private struct MockAuthProvider: AuthenticationProvider {
        let validTokens: [String: String] // token -> userId

        func verifyToken(_ token: String) async throws -> String {
            guard let userId = validTokens[token] else {
                throw AuthenticationError.invalidToken("Invalid token")
            }
            return userId
        }
    }

    // MARK: - Valid Token Tests

    func testValidTokenSetsAuthenticatedUser() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: ["valid-token-123": "user-abc"])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                // Verify authenticated context
                XCTAssertEqual(ctx.userId, "user-abc")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer valid-token-123")
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testValidTokenWithLowercaseBearer() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: ["token-456": "user-xyz"])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                XCTAssertEqual(ctx.userId, "user-xyz")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "bearer token-456")
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    // MARK: - Invalid Token Tests

    func testInvalidTokenAllowsAnonymousAccess() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: [:])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                // For auth: .none endpoints, should allow anonymous
                XCTAssertNil(ctx.userId)
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer invalid-token")
        }) { res async throws in
            // TestAPI.ListItems has auth: .none, so it should succeed
            XCTAssertEqual(res.status, .ok)
        }
    }

    // MARK: - No Token Tests

    func testNoTokenAllowsAnonymousForPublicEndpoints() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: [:])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                XCTAssertNil(ctx.userId)
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testNoTokenRejectsProtectedEndpoints() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: [:])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = ProtectedAPIServiceImpl()

        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret") { res async throws in
            // ProtectedAPI has auth: .required, so it should fail
            XCTAssertEqual(res.status, .unauthorized)

            let error = try res.content.decode(ErrorResponse.self)
            XCTAssertEqual(error.errorCode, "UNAUTHORIZED")
        }
    }

    // MARK: - Mixed Auth Scenarios

    func testProtectedEndpointWithValidToken() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: ["admin-token": "admin-user"])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = ProtectedAPIServiceImpl()

        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                XCTAssertEqual(ctx.userId, "admin-user")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer admin-token")
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testProtectedEndpointWithInvalidToken() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let provider = MockAuthProvider(validTokens: [:])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())

        let handler = ProtectedAPIServiceImpl()

        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer bad-token")
        }) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    // MARK: - Credential Position
    //
    // An endpoint is satisfied only by a credential presented where its declared scheme puts it.
    // The token used below is valid — the provider would accept it — so a passing request would
    // mean the position was ignored, not that the token was rejected.

    private static let goodToken = "admin-token"
    private static let goodUser = "admin-user"

    private func makeApp() async throws -> Application {
        let app = try await Application.make(.testing)
        let provider = MockAuthProvider(validTokens: [Self.goodToken: Self.goodUser])
        app.middleware.use(AuthMiddleware(provider: provider))
        app.middleware.use(APIContractErrorMiddleware())
        return app
    }

    /// A Bearer endpoint must not accept the token from the query string. Accepting it would put
    /// the credential into URLs, access logs and `Referer` headers.
    func testBearerEndpointRejectsCredentialInQueryString() async throws {
        let app = try await makeApp()
        defer { Task { try await app.asyncShutdown() } }

        let handler = ProtectedAPIServiceImpl()
        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                XCTFail("A query-string credential must not reach the handler of a .bearer endpoint")
                return try await handler.handle(input, context: ctx)
            }

        for query in ["access_token=\(Self.goodToken)",
                      "authorization=Bearer%20\(Self.goodToken)",
                      "token=\(Self.goodToken)"] {
            try await app.test(.GET, "/protected/secret?\(query)") { res async throws in
                XCTAssertEqual(res.status, .unauthorized, "query: \(query)")
            }
        }
    }

    /// Nor from a header of its own choosing — only `Authorization` carries a Bearer credential.
    func testBearerEndpointRejectsCredentialInAPIKeyHeader() async throws {
        let app = try await makeApp()
        defer { Task { try await app.asyncShutdown() } }

        let handler = ProtectedAPIServiceImpl()
        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                XCTFail("An x-api-key credential must not reach the handler of a .bearer endpoint")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret", beforeRequest: { req in
            req.headers.add(name: "x-api-key", value: Self.goodToken)
        }) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    /// The mirror image: an `.apiKey` endpoint is not satisfied by a Bearer header, even a valid
    /// one. The scheme the endpoint declared is the scheme that has to have proved the identity.
    func testAPIKeyEndpointRejectsBearerHeader() async throws {
        let app = try await makeApp()
        defer { Task { try await app.asyncShutdown() } }

        let handler = APIKeyAPIServiceImpl()
        app.mount(handler)
            .register(APIKeyAPI.GetSecret.self) { input, ctx in
                XCTFail("A Bearer credential must not satisfy an .apiKey endpoint")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/api-key-protected/secret", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer \(Self.goodToken)")
        }) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    /// Same for `.queryParam`, from either position. No authenticator for that scheme ships here,
    /// so the endpoint rejects rather than falling back to the Bearer one.
    func testQueryParamEndpointRejectsEveryPosition() async throws {
        let app = try await makeApp()
        defer { Task { try await app.asyncShutdown() } }

        let handler = QueryParamAPIServiceImpl()
        app.mount(handler)
            .register(QueryParamAPI.GetSecret.self) { input, ctx in
                XCTFail("No credential can satisfy a .queryParam endpoint while no authenticator for it is installed")
                return try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/query-protected/secret?access_token=\(Self.goodToken)") { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try await app.test(.GET, "/query-protected/secret", beforeRequest: { req in
            req.headers.add(name: .authorization, value: "Bearer \(Self.goodToken)")
        }) { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
}
