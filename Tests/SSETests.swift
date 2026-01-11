import XCTest
import XCTVapor
@testable import APIServer

final class SSETests: XCTestCase {

    // MARK: - SSEEvent Formatting

    func testSSEEventWithDataOnly() {
        let event = SSEEvent(data: "Hello, World!")
        let formatted = event.formatted()

        XCTAssertEqual(formatted, "data: Hello, World!\n\n")
    }

    func testSSEEventWithEventType() {
        let event = SSEEvent(data: "test data", event: "message")
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("event: message\n"))
        XCTAssertTrue(formatted.contains("data: test data\n"))
        XCTAssertTrue(formatted.hasSuffix("\n\n"))
    }

    func testSSEEventWithId() {
        let event = SSEEvent(data: "test data", id: "msg-123")
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("id: msg-123\n"))
        XCTAssertTrue(formatted.contains("data: test data\n"))
    }

    func testSSEEventWithRetry() {
        let event = SSEEvent(data: "test data", retry: 5000)
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("retry: 5000\n"))
        XCTAssertTrue(formatted.contains("data: test data\n"))
    }

    func testSSEEventWithAllFields() {
        let event = SSEEvent(
            data: "complete event",
            event: "update",
            id: "evt-456",
            retry: 3000
        )
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("event: update\n"))
        XCTAssertTrue(formatted.contains("id: evt-456\n"))
        XCTAssertTrue(formatted.contains("retry: 3000\n"))
        XCTAssertTrue(formatted.contains("data: complete event\n"))
        XCTAssertTrue(formatted.hasSuffix("\n\n"))
    }

    func testSSEEventWithMultilineData() {
        let event = SSEEvent(data: "line1\nline2\nline3")
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("data: line1\n"))
        XCTAssertTrue(formatted.contains("data: line2\n"))
        XCTAssertTrue(formatted.contains("data: line3\n"))
    }

    func testSSEEventComment() {
        let event = SSEEvent.comment("keepalive")
        let formatted = event.formatted()

        XCTAssertEqual(formatted, ": keepalive\n\n")
    }

    func testSSEEventFromJSON() throws {
        struct TestData: Codable {
            let message: String
            let count: Int
        }

        let data = TestData(message: "Hello", count: 42)
        let event = try SSEEvent.json(data, event: "test")
        let formatted = event.formatted()

        XCTAssertTrue(formatted.contains("event: test\n"))
        XCTAssertTrue(formatted.contains("data: "))
        XCTAssertTrue(formatted.contains("\"message\":\"Hello\""))
        XCTAssertTrue(formatted.contains("\"count\":42"))
    }

    func testSSEEventEquatable() {
        let event1 = SSEEvent(data: "test", event: "message", id: "1")
        let event2 = SSEEvent(data: "test", event: "message", id: "1")
        let event3 = SSEEvent(data: "different", event: "message", id: "1")

        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }

    func testSSEEventHashable() {
        let event1 = SSEEvent(data: "test", event: "message", id: "1")
        let event2 = SSEEvent(data: "test", event: "message", id: "1")

        var set = Set<SSEEvent>()
        set.insert(event1)
        set.insert(event2)

        XCTAssertEqual(set.count, 1)
    }

    // MARK: - SSE Constants

    func testSSEConstants() {
        XCTAssertEqual(SSEConstants.contentType, "text/event-stream")
        XCTAssertEqual(SSEConstants.cacheControl, "no-cache")
        XCTAssertEqual(SSEConstants.connection, "keep-alive")
        XCTAssertEqual(SSEConstants.defaultRetry, 3000)
    }

    // MARK: - SSE Route Registration

    func testSSERouteReturnsCorrectHeaders() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        app.get("events") { _ async throws -> Response in
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: SSEConstants.contentType)
            headers.add(name: .cacheControl, value: SSEConstants.cacheControl)
            headers.add(name: .connection, value: SSEConstants.connection)

            return Response(
                status: .ok,
                headers: headers,
                body: .init(string: "data: test\n\n")
            )
        }

        try await app.test(.GET, "/events") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType?.serialize(), "text/event-stream")
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-cache")
            XCTAssertEqual(res.headers.first(name: .connection), "keep-alive")
        }
    }

    func testSSEEventFieldOrder() {
        // SSE spec: event, id, retry, then data
        let event = SSEEvent(
            data: "payload",
            event: "update",
            id: "123",
            retry: 5000
        )
        let formatted = event.formatted()

        // event should come before id
        let eventIndex = formatted.range(of: "event:")!.lowerBound
        let idIndex = formatted.range(of: "id:")!.lowerBound
        let retryIndex = formatted.range(of: "retry:")!.lowerBound
        let dataIndex = formatted.range(of: "data:")!.lowerBound

        XCTAssertTrue(eventIndex < idIndex)
        XCTAssertTrue(idIndex < retryIndex)
        XCTAssertTrue(retryIndex < dataIndex)
    }

    func testEmptyDataEvent() {
        // Event with only event type, no data
        let event = SSEEvent(event: "ping")
        let formatted = event.formatted()

        XCTAssertEqual(formatted, "event: ping\n\n")
    }

    func testSSEEventWithEmptyString() {
        let event = SSEEvent(data: "")
        let formatted = event.formatted()

        XCTAssertEqual(formatted, "data: \n\n")
    }

    // MARK: - Error Handling

    func testSSEEncodingError() {
        let error = SSEEncodingError.invalidUTF8
        XCTAssertEqual(error.errorDescription, "Failed to encode value as UTF-8 string")
    }
}
