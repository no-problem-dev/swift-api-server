import XCTest
import XCTVapor
@testable import APIServer

final class DecodeTests: XCTestCase {

    // MARK: - Path Parameter Decoding

    func testPathParameterExtraction() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = CaptureHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/my-item-123") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let item = try res.content.decode(TestItem.self)
            XCTAssertEqual(item.id, "my-item-123")
        }
    }

    func testPathParameterWithSpecialCharacters() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = CaptureHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        // URLエンコードされた値
        try await app.test(.GET, "/test/items/item%2Fwith%2Fslashes") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let item = try res.content.decode(TestItem.self)
            XCTAssertEqual(item.id, "item/with/slashes")
        }
    }

    // MARK: - Query Parameter Decoding

    func testQueryParameterExtraction() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = QueryCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items?limit=25&offset=100") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastLimit, 25)
            XCTAssertEqual(handler.lastOffset, 100)
        }
    }

    func testOptionalQueryParametersWhenMissing() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = QueryCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNil(handler.lastLimit)
            XCTAssertNil(handler.lastOffset)
        }
    }

    func testPartialQueryParameters() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = QueryCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items?limit=10") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastLimit, 10)
            XCTAssertNil(handler.lastOffset)
        }
    }

    // MARK: - Body Decoding

    func testBodyDecoding() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = BodyCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.CreateItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.POST, "/test/items", beforeRequest: { req async throws in
            try req.content.encode(CreateItemBody(name: "My New Item"))
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastName, "My New Item")
        }
    }

    func testBodyDecodingWithJapanese() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = BodyCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.CreateItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.POST, "/test/items", beforeRequest: { req async throws in
            try req.content.encode(CreateItemBody(name: "日本語アイテム"))
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastName, "日本語アイテム")
        }
    }

    // MARK: - Handler Context Building

    func testBuildAnonymousContext() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = ContextCapturingHandler()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(handler.wasAnonymous)
        }
    }

    func testBuildAuthenticatedContext() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = ContextCapturingHandler()

        app.grouped(MockAuthMiddleware(userId: "user-abc"))
            .mount(TestAPI.self, handler: handler)
            .register(TestAPI.ListItems.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertFalse(handler.wasAnonymous)
            XCTAssertEqual(handler.authenticatedUserId, "user-abc")
        }
    }

    func testRequiredAuthThrowsWhenAnonymous() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ProtectedAPIHandlerImpl()

        app.mount(ProtectedAPI.self, handler: handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret") { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
}

// MARK: - Capture Handlers

private final class CaptureHandler: TestAPIHandler, @unchecked Sendable {
    func handle(_ input: TestAPI.ListItems, context: HandlerContext) async throws -> [TestItem] {
        []
    }

    func handle(_ input: TestAPI.GetItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: HandlerContext) async throws {}
}

private final class QueryCapturingHandler: TestAPIHandler, @unchecked Sendable {
    var lastLimit: Int?
    var lastOffset: Int?

    func handle(_ input: TestAPI.ListItems, context: HandlerContext) async throws -> [TestItem] {
        lastLimit = input.limit
        lastOffset = input.offset
        return []
    }

    func handle(_ input: TestAPI.GetItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: HandlerContext) async throws {}
}

private final class BodyCapturingHandler: TestAPIHandler, @unchecked Sendable {
    var lastName: String?

    func handle(_ input: TestAPI.ListItems, context: HandlerContext) async throws -> [TestItem] {
        []
    }

    func handle(_ input: TestAPI.GetItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: HandlerContext) async throws -> TestItem {
        lastName = input.body.name
        return TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: HandlerContext) async throws {}
}

private final class ContextCapturingHandler: TestAPIHandler, @unchecked Sendable {
    var wasAnonymous: Bool = true
    var authenticatedUserId: String?

    func handle(_ input: TestAPI.ListItems, context: HandlerContext) async throws -> [TestItem] {
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

    func handle(_ input: TestAPI.GetItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: HandlerContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: HandlerContext) async throws {}
}

// MARK: - Mock Auth Middleware

import Vapor

private struct MockAuthMiddleware: AsyncMiddleware {
    let userId: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.auth.login(AuthenticatedUser(id: userId))
        return try await next.respond(to: request)
    }
}
