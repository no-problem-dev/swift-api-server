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
}
