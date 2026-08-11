import XCTest
import XCTVapor
@testable import APIServer

/// Regression tests proving that headers a middleware adds survive all the way to the wire.
///
/// `addingHeaders` used to be an opt-in refinement, and a type that did not adopt it silently
/// returned itself unchanged. The adapter then discarded the wrapper's headers and returned the
/// underlying response as-is. Both failures were silent, and together they dropped CORS headers
/// from every streaming response.
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

    /// The wrapper keeps added headers instead of discarding them.
    func testAnyStreamResponseRetainsAddedHeaders() {
        let underlying = Response(status: .ok)
        let wrapped = AnyStreamResponse(
            wrapping: BasicDataResponse(status: .ok, headers: ["X-Base": "1"], body: Data()),
            underlying: underlying
        )

        let result = wrapped.addingHeaders(["Access-Control-Allow-Origin": "*"])

        XCTAssertEqual(result.headers["X-Base"], "1")
        XCTAssertEqual(result.headers["Access-Control-Allow-Origin"], "*")
        XCTAssertIdentical(
            result.underlyingResponse as? Response, underlying,
            "underlying は同じ実体を持ち回る（ストリームボディを失わないため）"
        )
    }

    /// The adapter copies the wrapper's headers onto the response that is actually written.
    func testAdapterAppliesStreamHeadersToUnderlyingResponse() {
        let underlying = Response(status: .ok)
        underlying.headers.replaceOrAdd(name: "X-Original", value: "keep")

        let wrapped = AnyStreamResponse(
            wrapping: BasicDataResponse(status: .ok, headers: [:], body: Data()),
            underlying: underlying
        ).addingHeaders(["Access-Control-Allow-Origin": "*"])

        let converted = VaporMiddlewareAdapter.toVaporResponse(wrapped)

        XCTAssertEqual(converted.headers.first(name: "Access-Control-Allow-Origin"), "*")
        XCTAssertEqual(converted.headers.first(name: "X-Original"), "keep")
    }
}
