import Foundation
import XCTest
import XCTVapor
@testable import APIServer

/// Regression tests proving that headers a middleware adds survive all the way to the wire.
///
/// `addingHeaders` used to be an opt-in refinement, and a type that did not adopt it silently
/// returned itself unchanged, which dropped CORS headers from streaming responses. It is a
/// requirement of the base protocol now, so forgetting it is a compile error — but the path that
/// carries a *streaming* response back through the chain still has to be exercised against a real
/// route, not against a stand-in.
final class ResponseHeaderTests: XCTestCase {

    func testDataResponseCarriesAddedHeaders() {
        let base = BasicDataResponse(status: .ok, headers: ["X-Base": "1"], body: Data())
        let result = base.addingHeaders(["X-Added": "2"])

        XCTAssertEqual(result.headers["X-Base"], "1")
        XCTAssertEqual(result.headers["X-Added"], "2")
    }

    func testAddedHeaderReplacesSameName() {
        let base = BasicDataResponse(status: .ok, headers: ["X-Dup": "old"], body: Data())
        let result = base.addingHeaders(["X-Dup": "new"])

        XCTAssertEqual(result.headers["X-Dup"], "new")
    }

    /// A field added under a different case replaces the existing one rather than sitting beside
    /// it, so the response cannot go out carrying the same field twice.
    func testAddedHeaderReplacesSameNameWrittenInAnotherCase() {
        let base = BasicDataResponse(status: .ok, headers: ["X-Dup": "old"], body: Data())
        let result = base.addingHeaders(["x-dup": "new"])

        XCTAssertEqual(result.headers["X-Dup"], "new")
        XCTAssertEqual(result.headers.all.count, 1)
    }

    /// The path that actually carries a streaming body back through the middleware chain.
    ///
    /// A real SSE route, a real middleware, and a body that is still produced over time: the
    /// response has to reach the client with the SSE headers, the header the middleware added, and
    /// its events.
    func testMiddlewareHeadersReachAStreamingResponseWithoutBufferingItAway() async throws {
        let server = try await VaporServerApplication(environment: .testing)
        defer { Task { try await server.shutdown() } }

        server.use(CORSServerMiddleware(configuration: .custom(allowedOrigins: ["https://allowed.example"])))
        server.sse("events") {
            AsyncStream<SSEEvent> { continuation in
                continuation.yield(SSEEvent(data: "one", event: "tick"))
                continuation.yield(SSEEvent(data: "two", event: "tick"))
                continuation.finish()
            }
        }

        try await server.app.test(
            .GET, "/events", headers: ["origin": "https://allowed.example"]
        ) { res async throws in
            XCTAssertEqual(res.headers.first(name: .contentType), SSEConstants.contentType)
            XCTAssertEqual(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "https://allowed.example"
            )
            XCTAssertTrue(res.body.string.contains("data: one"), res.body.string)
            XCTAssertTrue(res.body.string.contains("data: two"), res.body.string)
        }
    }
}
