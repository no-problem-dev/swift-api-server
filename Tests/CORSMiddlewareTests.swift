import Foundation
import XCTest
import XCTVapor
@testable import APIServer

/// The access-control policy, exercised through the real middleware chain.
///
/// The negative cases lead: an origin that is not on the allow-list must not be answered with an
/// allow header, and it must stay rejected however the client wrote the header name. HTTP/2 and
/// HTTP/3 require field names to be sent lowercased, so `origin` is the form a modern browser
/// actually sends and the form the allow-list has to keep working against.
final class CORSMiddlewareTests: XCTestCase {

    private static let allowList = CORSConfiguration.custom(
        allowedOrigins: ["https://allowed.example"],
        allowCredentials: true
    )

    /// A server with the policy installed, serving `GET /ping` and `GET /vary`.
    ///
    /// `/vary` answers with a `Vary` of its own, so the test can prove the middleware extends it
    /// rather than overwriting it.
    private func makeApp(_ configuration: CORSConfiguration) async throws -> Application {
        let app = try await Application.make(.testing)
        app.middleware.use(
            VaporMiddlewareAdapter(
                middleware: CORSServerMiddleware(configuration: configuration),
                logger: app.logger
            )
        )
        app.get("ping") { _ in "pong" }
        app.get("vary") { _ -> Response in
            let response = Response(status: .ok)
            response.headers.replaceOrAdd(name: "Vary", value: "Accept-Encoding")
            return response
        }
        return app
    }

    // MARK: - Allow-list: the origin is not on it

    func testDisallowedOriginIsNotAllowed() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["Origin": "https://evil.example"]) { res async throws in
            XCTAssertNil(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "an origin outside the allow-list must not be granted access"
            )
        }
    }

    /// The same rejection, with the field name written the way HTTP/2 requires.
    ///
    /// This is the case that must not regress when the lookup is made case-insensitive: finding
    /// the header is not the same as trusting it.
    func testDisallowedLowercaseOriginIsNotAllowed() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://evil.example"]) { res async throws in
            XCTAssertNil(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "case-insensitive lookup must not turn into trusting every origin"
            )
        }
    }

    func testDisallowedOriginIsNotAllowedOnPreflight() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.OPTIONS, "/ping", headers: ["origin": "https://evil.example"]) { res async throws in
            XCTAssertEqual(res.status, .noContent)
            XCTAssertNil(res.headers.first(name: "Access-Control-Allow-Origin"))
        }
    }

    /// An origin that differs only in case is a different origin — hosts are case-insensitive in
    /// DNS but the allow-list is compared as written, and a browser sends the origin verbatim.
    func testOriginMatchingIsExact() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://allowed.example.evil.test"]) { res async throws in
            XCTAssertNil(res.headers.first(name: "Access-Control-Allow-Origin"))
        }
    }

    // MARK: - Allow-list: the origin is on it

    func testAllowedOriginIsEchoed() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["Origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "https://allowed.example"
            )
        }
    }

    /// The field name as HTTP/2 sends it. Missing this made the allow-list unreachable — no
    /// browser speaking HTTP/2 was ever granted access.
    func testAllowedOriginIsEchoedWhenTheFieldNameIsLowercased() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "https://allowed.example"
            )
        }
    }

    /// With `["*"]` the origin is echoed rather than answered with `*`, which is the only form a
    /// browser accepts for a credentialed request. Reading the field name case-sensitively fell
    /// through to the literal `*` and broke exactly that case.
    func testWildcardEchoesTheOriginRatherThanAnswringWithStar() async throws {
        let app = try await makeApp(.default())
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://any.example"]) { res async throws in
            XCTAssertEqual(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "https://any.example"
            )
        }
    }

    func testWildcardAnswersWithStarWhenNoOriginIsSent() async throws {
        let app = try await makeApp(.default())
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping") { res async throws in
            XCTAssertEqual(res.headers.first(name: "Access-Control-Allow-Origin"), "*")
        }
    }

    // MARK: - Cacheability

    /// Without `Vary: Origin` a shared cache stores one origin's allow header under the URL alone
    /// and serves it to the next origin that asks — which hands an origin outside the allow-list
    /// exactly the header the allow-list refused it.
    func testAllowedOriginResponseVariesByOrigin() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(res.headers.first(name: "Vary"), "Origin")
        }
    }

    /// The rejection is just as origin-dependent as the grant, so it must not be cached across
    /// origins either.
    func testDisallowedOriginResponseVariesByOrigin() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/ping", headers: ["origin": "https://evil.example"]) { res async throws in
            XCTAssertEqual(res.headers.first(name: "Vary"), "Origin")
        }
    }

    /// A handler that already varies its response keeps doing so; `Origin` is added to the list
    /// rather than replacing it.
    func testVaryIsExtendedNotOverwritten() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.GET, "/vary", headers: ["origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(res.headers.first(name: "Vary"), "Accept-Encoding, Origin")
        }
    }

    /// A handler that already varies by origin is left alone rather than gaining a duplicate.
    func testVaryIsNotDuplicated() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.middleware.use(
            VaporMiddlewareAdapter(
                middleware: CORSServerMiddleware(configuration: Self.allowList),
                logger: app.logger
            )
        )
        app.get("already") { _ -> Response in
            let response = Response(status: .ok)
            response.headers.replaceOrAdd(name: "vary", value: "origin")
            return response
        }

        try await app.test(.GET, "/already", headers: ["origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(res.headers["Vary"].count, 1)
            XCTAssertEqual(res.headers.first(name: "Vary")?.lowercased(), "origin")
        }
    }

    // MARK: - Preflight

    func testPreflightIsAnsweredWithoutReachingTheHandler() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.OPTIONS, "/ping", headers: ["origin": "https://allowed.example"]) { res async throws in
            XCTAssertEqual(res.status, .noContent)
            XCTAssertEqual(
                res.headers.first(name: "Access-Control-Allow-Origin"),
                "https://allowed.example"
            )
            XCTAssertEqual(res.headers.first(name: "Access-Control-Allow-Credentials"), "true")
            XCTAssertEqual(res.headers.first(name: "Access-Control-Max-Age"), "600")
            XCTAssertEqual(res.body.string, "")
        }
    }

    /// Looking a field up without regard to case must not change how it is written on the way out.
    /// The preflight answer is built from scratch by the middleware, so it is where a folded name
    /// would escape onto the wire.
    func testPreflightWritesHeaderNamesAsSpelled() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.OPTIONS, "/ping", headers: ["origin": "https://allowed.example"]) { res async throws in
            let names = res.headers.map(\.name)
            XCTAssertTrue(names.contains("Access-Control-Allow-Origin"), "\(names)")
            XCTAssertTrue(names.contains("Vary"), "\(names)")
        }
    }

    func testPreflightAdvertisesTheConfiguredMethodsAndHeaders() async throws {
        let app = try await makeApp(Self.allowList)
        defer { Task { try await app.asyncShutdown() } }

        try await app.test(.OPTIONS, "/ping", headers: ["origin": "https://allowed.example"]) { res async throws in
            let methods = res.headers.first(name: "Access-Control-Allow-Methods") ?? ""
            XCTAssertTrue(methods.contains("GET"))
            XCTAssertTrue(methods.contains("DELETE"))

            let allowedHeaders = res.headers.first(name: "Access-Control-Allow-Headers") ?? ""
            XCTAssertTrue(allowedHeaders.contains("Authorization"))
        }
    }
}
