import XCTest
import XCTVapor
@testable import APIServer

/// ミドルウェアが足したヘッダーが実際に送出されるまで届くことの回帰テスト。
///
/// 以前は `addingHeaders` が `HeaderModifiableResponse` 任意適合で、未適合の
/// `AnyStreamResponse` には黙って元のレスポンスを返していた。さらに
/// `VaporMiddlewareAdapter` は `AnyStreamResponse.headers` を捨てて underlying を
/// そのまま返していたため、**ストリームレスポンスに対して CORS ヘッダーが二重に無言で落ちた**。
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

    /// 本命: 型消去ストリームでもヘッダーが保持される（旧実装はここで黙って落ちた）。
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

    /// 本命: snapshot 側のヘッダーが、実際に送出される underlying へ反映される。
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
