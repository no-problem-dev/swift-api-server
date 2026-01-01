import XCTest
import XCTVapor
import APIContract
@testable import APIServer

final class ErrorMiddlewareTests: XCTestCase {

    // MARK: - APIContractError Handling

    func testAPIContractErrorConvertsToJSON() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ErrorThrowingHandler(error: TestAPIError.itemNotFound(id: "abc123"))

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/abc123") { res async throws in
            XCTAssertEqual(res.status, .notFound)

            let error = try res.content.decode(ErrorResponse.self)
            XCTAssertEqual(error.errorCode, "ITEM_NOT_FOUND")
            XCTAssertEqual(error.message, "Item not found: abc123")
        }
    }

    func testAPIContractErrorWithBadRequestStatus() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ErrorThrowingHandler(error: TestAPIError.invalidName(reason: "Too short"))

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/abc") { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let error = try res.content.decode(ErrorResponse.self)
            XCTAssertEqual(error.errorCode, "INVALID_NAME")
            XCTAssertTrue(error.message.contains("Too short"))
        }
    }

    func testAPIContractErrorWithUnauthorizedStatus() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ErrorThrowingHandler(error: TestAPIError.unauthorized)

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/abc") { res async throws in
            XCTAssertEqual(res.status, .unauthorized)

            let error = try res.content.decode(ErrorResponse.self)
            XCTAssertEqual(error.errorCode, "UNAUTHORIZED")
        }
    }

    // MARK: - Decoding Error Handling

    func testDecodingErrorConvertsTo400() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = TestAPIHandlerImpl()

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.CreateItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        // Send invalid JSON
        // Note: VaporはJSONパースエラーをAbortErrorとして処理するため、
        // DecodingErrorではなくVAPOR_ABORTとなる
        try await app.test(.POST, "/test/items", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = .init(string: "{ invalid json }")
        }) { res async throws in
            XCTAssertEqual(res.status, .badRequest)

            let error = try res.content.decode(ErrorResponse.self)
            // VaporのJSONパースエラーはAbortErrorとして処理される
            XCTAssertEqual(error.errorCode, "VAPOR_ABORT")
        }
    }

    // MARK: - Content-Type Header

    func testErrorResponseHasJSONContentType() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(APIContractErrorMiddleware())

        let handler = ErrorThrowingHandler(error: TestAPIError.itemNotFound(id: "test"))

        app.mount(TestAPI.self, handler: handler)
            .register(TestAPI.GetItem.self) { input, ctx in
                try await handler.handle(input, context: ctx)
            }

        try await app.test(.GET, "/test/items/test") { res async throws in
            XCTAssertEqual(res.headers.contentType, .json)
        }
    }
}

// MARK: - Error Throwing Handler

private final class ErrorThrowingHandler: TestAPIHandler, @unchecked Sendable {
    let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func handle(_ input: TestAPI.ListItems, context: HandlerContext) async throws -> [TestItem] {
        throw error
    }

    func handle(_ input: TestAPI.GetItem, context: HandlerContext) async throws -> TestItem {
        throw error
    }

    func handle(_ input: TestAPI.CreateItem, context: HandlerContext) async throws -> TestItem {
        throw error
    }

    func handle(_ input: TestAPI.DeleteItem, context: HandlerContext) async throws {
        throw error
    }
}
