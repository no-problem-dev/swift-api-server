import Foundation
import XCTest
import XCTVapor
@testable import APIServer

/// The read-only view of a request that middleware sees.
///
/// Header lookup is the load-bearing part: HTTP field names are case-insensitive by specification,
/// and HTTP/2 and HTTP/3 require them to be sent lowercased. A middleware that looks for `Origin`
/// or `Content-Type` has to find the field whatever case it arrived in, or it silently behaves as
/// though the client sent nothing.
final class ServerRequestTests: XCTestCase {

    /// Runs one request through a middleware that records what it saw.
    @discardableResult
    private func capture(
        headers: HTTPHeaders,
        path: String = "/ping"
    ) async throws -> RequestSpy {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let spy = RequestSpy()
        app.middleware.use(VaporMiddlewareAdapter(middleware: spy, logger: app.logger))
        app.get("ping") { _ in "pong" }
        app.get("items", ":itemId") { _ in "pong" }

        try await app.test(.GET, path, headers: headers) { _ async throws in }
        return spy
    }

    // MARK: - Header lookup

    func testHeaderIsFoundWhenTheClientSentItLowercased() async throws {
        let spy = try await capture(headers: ["content-type": "application/json"])

        XCTAssertEqual(spy.headers?["Content-Type"], "application/json")
    }

    func testHeaderIsFoundWhenTheClientSentItCapitalized() async throws {
        let spy = try await capture(headers: ["Content-Type": "application/json"])

        XCTAssertEqual(spy.headers?["content-type"], "application/json")
    }

    func testHeaderIsFoundWhateverCaseTheLookupUses() async throws {
        let spy = try await capture(headers: ["X-Request-Id": "abc"])

        XCTAssertEqual(spy.headers?["x-request-id"], "abc")
        XCTAssertEqual(spy.headers?["X-REQUEST-ID"], "abc")
        XCTAssertTrue(spy.headers?.contains("x-Request-Id") == true)
    }

    func testAbsentHeaderIsNil() async throws {
        let spy = try await capture(headers: [:])

        XCTAssertNil(spy.headers?["Authorization"])
        XCTAssertFalse(spy.headers?.contains("Authorization") == true)
    }

    // MARK: - The rest of the view

    func testQueryParametersArePercentDecoded() async throws {
        let spy = try await capture(headers: [:], path: "/ping?q=hello%20world&n=2")

        XCTAssertEqual(spy.queryParameters?["q"], "hello world")
        XCTAssertEqual(spy.queryParameters?["n"], "2")
    }

    func testMethodIsUppercased() async throws {
        let spy = try await capture(headers: [:])

        XCTAssertEqual(spy.method, "GET")
    }
}

// MARK: - Spy

/// Records the view handed to a middleware, then continues down the chain unchanged.
final class RequestSpy: ServerMiddleware, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: (headers: HTTPHeaderFields, query: [String: String], method: String)?

    var headers: HTTPHeaderFields? { read()?.headers }
    var queryParameters: [String: String]? { read()?.query }
    var method: String? { read()?.method }

    func handle(
        request: any ServerRequest,
        next: @escaping @Sendable () async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        record((request.headers, request.queryParameters, request.method))
        return try await next()
    }

    private func record(_ value: (headers: HTTPHeaderFields, query: [String: String], method: String)) {
        lock.lock(); defer { lock.unlock() }
        recorded = value
    }

    private func read() -> (headers: HTTPHeaderFields, query: [String: String], method: String)? {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}
