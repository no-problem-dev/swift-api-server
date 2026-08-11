import XCTest
import XCTVapor
@testable import APIServer

/// How a server is started and stopped.
final class ServerLifecycleTests: XCTestCase {

    /// The documented shape is `defer { Task { try? await server.shutdown() } }`, after which the
    /// server is released. Shutting down a second time on the way out trips the framework's own
    /// `assert(!didShutdown)` and takes the process with it — and being dispatched from `deinit`,
    /// it is not something a caller can catch or opt out of.
    func testShutdownFollowedByDeallocationDoesNotShutDownTwice() async throws {
        do {
            let server = try await VaporServerApplication(environment: .testing)
            try await server.shutdown()
        }

        // A second shutdown would be dispatched onto a detached task, so give it time to land.
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    func testShutdownStopsAServerThatWasNeverRun() async throws {
        let server = try await VaporServerApplication(environment: .testing)
        server.get("health") { "OK" }

        try await server.shutdown()
    }

    func testEnvironmentIsTheOneTheServerWasCreatedFor() async throws {
        let server = try await VaporServerApplication(environment: .production)
        defer { Task { try await server.shutdown() } }

        XCTAssertEqual(server.environment, .production)
        XCTAssertTrue(server.environment.isProduction)
    }
}
