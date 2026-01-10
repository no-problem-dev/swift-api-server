import XCTest
import XCTVapor
@testable import APIServer

final class MountTests: XCTestCase {

    // MARK: - Route Registration

    func testMountCreatesCorrectBasePath() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testMountWithPathParameter() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = MockGetItemHandler()

        app.mount(handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/abc123") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let item = try res.content.decode(TestItem.self)
            XCTAssertEqual(item.id, "abc123")
        }
    }

    func testMountWithQueryParameters() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = MockListItemsHandler()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items?limit=10&offset=5") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastLimit, 10)
            XCTAssertEqual(handler.lastOffset, 5)
        }
    }

    func testMountWithBody() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = MockCreateItemHandler()

        app.mount(handler)
            .register(TestAPI.CreateItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        let body = CreateItemBody(name: "Test Item")

        try await app.test(.POST, "/test/items", beforeRequest: { req async throws in
            try req.content.encode(body)
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let item = try res.content.decode(TestItem.self)
            XCTAssertEqual(item.name, "Test Item")
        }
    }

    func testMountWithEmptyOutput() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = MockDeleteItemHandler()

        app.mount(handler)
            .register(TestAPI.DeleteItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.DELETE, "/test/items/xyz789") { res async throws in
            XCTAssertEqual(res.status, .noContent)
        }
    }

    // MARK: - HTTP Methods

    func testCorrectHTTPMethodMapping() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = TestAPIServiceImpl()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }
            .register(TestAPI.CreateItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        // GET should work
        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }

        // POST to list endpoint should work because CreateItem is registered
        try await app.test(.POST, "/test/items", beforeRequest: { req async throws in
            try req.content.encode(CreateItemBody(name: "Test"))
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
        }

        // PUT should not be registered
        try await app.test(.PUT, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    // MARK: - Authentication Context

    func testAnonymousContext() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = ContextCheckingHandler()

        app.mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(handler.wasAnonymous)
        }
    }

    func testAuthenticatedContext() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = ContextCheckingHandler()

        app.grouped(MockAuthMiddleware())
            .mount(handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertFalse(handler.wasAnonymous)
            XCTAssertEqual(handler.authenticatedUserId, "test-user-123")
        }
    }

    // MARK: - Protected API (auth required)

    func testProtectedAPIRequiresAuth() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ProtectedAPIServiceImpl()

        // Without auth middleware
        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret") { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testProtectedAPIWithAuth() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = ProtectedAPIServiceImpl()

        // With auth middleware
        app.grouped(MockAuthMiddleware())
            .mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let data = try res.content.decode(SecretData.self)
            XCTAssertEqual(data.secret, "top-secret-value")
        }
    }
}

// MARK: - Mock Handlers

private final class MockGetItemHandler: TestAPIService, @unchecked Sendable {
    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] { [] }
    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }
    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }
    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

private final class MockListItemsHandler: TestAPIService, @unchecked Sendable {
    var lastLimit: Int?
    var lastOffset: Int?

    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] {
        lastLimit = input.limit
        lastOffset = input.offset
        return []
    }
    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }
    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }
    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

private final class MockCreateItemHandler: TestAPIService, @unchecked Sendable {
    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] { [] }
    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }
    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: UUID().uuidString, name: input.body.name)
    }
    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

private final class MockDeleteItemHandler: TestAPIService, @unchecked Sendable {
    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] { [] }
    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }
    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }
    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {
        // Success - do nothing
    }
}

private final class ContextCheckingHandler: TestAPIService, @unchecked Sendable {
    var wasAnonymous: Bool = true
    var authenticatedUserId: String?

    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] {
        switch context {
        case .anonymous:
            wasAnonymous = true
            authenticatedUserId = nil
        case .authenticated(let userId):
            wasAnonymous = false
            authenticatedUserId = userId
        }
        return []
    }
    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }
    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }
    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

// MARK: - Mock Auth Middleware

import Vapor

private struct MockAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.auth.login(AuthenticatedUser(id: "test-user-123"))
        return try await next.respond(to: request)
    }
}
