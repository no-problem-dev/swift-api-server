import XCTest
import XCTVapor
@testable import APIServer

final class DecodeTests: XCTestCase {

    // MARK: - Path Parameter Decoding

    func testPathParameterExtraction() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = CaptureHandler()

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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

        app.mount(handler)
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
            .mount(handler)
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

        let handler = ProtectedAPIServiceImpl()

        app.mount(handler)
            .register(ProtectedAPI.GetSecret.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/protected/secret") { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    // MARK: - Nested Resource Path Parameter Tests

    /// basePathにパスパラメータ、subPathが空のケース
    /// GET /v1/books/:bookId/chats
    func testNestedResourceListWithBasePathParam() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = NestedResourceCapturingHandler()

        app.mount(handler)
            .register(NestedResourceAPI.List.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/v1/books/book-123/chats") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastBookId, "book-123")
        }
    }

    /// basePathにパスパラメータ、subPathにも追加パラメータのケース
    /// GET /v1/books/:bookId/chats/:chatId
    func testNestedResourceGetWithMultiplePathParams() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = NestedResourceCapturingHandler()

        app.mount(handler)
            .register(NestedResourceAPI.Get.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/v1/books/book-123/chats/chat-456") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastBookId, "book-123")
            XCTAssertEqual(handler.lastChatId, "chat-456")
        }
    }

    /// basePathにパスパラメータ + ボディのケース
    /// POST /v1/books/:bookId/chats
    func testNestedResourceCreateWithBasePathParamAndBody() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = NestedResourceCapturingHandler()

        app.mount(handler)
            .register(NestedResourceAPI.Create.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.POST, "/v1/books/book-789/chats", beforeRequest: { req async throws in
            try req.content.encode(CreateItemBody(name: "New Chat Message"))
        }) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastBookId, "book-789")
            XCTAssertEqual(handler.lastName, "New Chat Message")
        }
    }

    /// DELETE: 複数パスパラメータのケース
    /// DELETE /v1/books/:bookId/chats/:chatId
    func testNestedResourceDeleteWithMultiplePathParams() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = NestedResourceCapturingHandler()

        app.mount(handler)
            .register(NestedResourceAPI.Delete.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.DELETE, "/v1/books/book-abc/chats/chat-xyz") { res async throws in
            XCTAssertEqual(res.status, .noContent)
            XCTAssertEqual(handler.lastBookId, "book-abc")
            XCTAssertEqual(handler.lastChatId, "chat-xyz")
        }
    }

    /// UUID形式のパスパラメータのケース
    func testNestedResourceWithUUIDPathParams() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let handler = NestedResourceCapturingHandler()

        app.mount(handler)
            .register(NestedResourceAPI.Get.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        let bookId = "927AC2D9-FBB3-4F6D-9EE4-822E8788EC44"
        let chatId = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"

        try await app.test(.GET, "/v1/books/\(bookId)/chats/\(chatId)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(handler.lastBookId, bookId)
            XCTAssertEqual(handler.lastChatId, chatId)
        }
    }
}

// MARK: - Capture Handlers

private final class CaptureHandler: TestAPIService, @unchecked Sendable {
    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] {
        []
    }

    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

private final class QueryCapturingHandler: TestAPIService, @unchecked Sendable {
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

private final class BodyCapturingHandler: TestAPIService, @unchecked Sendable {
    var lastName: String?

    func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] {
        []
    }

    func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        TestItem(id: input.itemId, name: "Test")
    }

    func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        lastName = input.body.name
        return TestItem(id: "new", name: input.body.name)
    }

    func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {}
}

private final class ContextCapturingHandler: TestAPIService, @unchecked Sendable {
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
    let userId: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.auth.login(AuthenticatedUser(id: userId))
        return try await next.respond(to: request)
    }
}

// MARK: - Nested Resource Capturing Handler

private final class NestedResourceCapturingHandler: NestedResourceAPIService, @unchecked Sendable {
    var lastBookId: String?
    var lastChatId: String?
    var lastName: String?

    func handle(_ input: NestedResourceAPI.List, context: ServiceContext) async throws -> [TestItem] {
        lastBookId = input.bookId
        return [TestItem(id: "chat-1", name: "Test Chat")]
    }

    func handle(_ input: NestedResourceAPI.Get, context: ServiceContext) async throws -> TestItem {
        lastBookId = input.bookId
        lastChatId = input.chatId
        return TestItem(id: input.chatId, name: "Test Chat")
    }

    func handle(_ input: NestedResourceAPI.Create, context: ServiceContext) async throws -> TestItem {
        lastBookId = input.bookId
        lastName = input.body.name
        return TestItem(id: "new-chat", name: input.body.name)
    }

    func handle(_ input: NestedResourceAPI.Delete, context: ServiceContext) async throws {
        lastBookId = input.bookId
        lastChatId = input.chatId
    }
}
