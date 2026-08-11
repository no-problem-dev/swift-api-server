import Foundation
internal import Vapor
import APIContract

/// Builds the streaming response and the handler context shared by every SSE route family.
///
/// The three route extensions registered identical bodies; the framework-specific parts live here
/// so they exist once.
enum VaporSSEBuilder {
    /// Turns a sequence of events into a streaming response.
    ///
    /// Order matters: the body has to be built before the response, and the headers set after it,
    /// or the framework replaces the streaming body's headers. See
    /// https://forums.swift.org/t/re-stream-chunked-data-server-sent-events-from-another-web-service-through-the-vapor-endpoint/65375
    ///
    /// The stream is consumed on a detached task. If it throws, the error is logged and the body
    /// is terminated normally, so the client sees a clean end of stream rather than a failure.
    static func buildSSEResponse<S: AsyncSequence & Sendable>(
        from stream: S,
        request: Request
    ) -> Response where S.Element == SSEEvent {
        // Step 1: build the body first.
        let body = Response.Body(stream: { writer in
            Task {
                do {
                    // A comment written immediately flushes the headers, so the client sees
                    // the connection open without waiting for a first event.
                    let initComment = ": SSE stream initialized\n\n"
                    if let initData = initComment.data(using: .utf8) {
                        _ = writer.write(.buffer(.init(data: initData)))
                    }

                    var eventCount = 0
                    for try await event in stream {
                        eventCount += 1
                        let formatted = event.formatted()
                        if let data = formatted.data(using: .utf8) {
                            _ = writer.write(.buffer(.init(data: data)))
                        }
                    }

                    request.logger.info("SSE: Stream completed with \(eventCount) events")
                } catch {
                    request.logger.error("SSE stream error: \(error)")
                }
                _ = writer.write(.end)
            }
        })

        // Step 2: hand the body to the response.
        let response = Response(status: .ok, body: body)

        // Step 3: set the headers last.
        response.headers.replaceOrAdd(name: .contentType, value: SSEConstants.contentType)
        response.headers.replaceOrAdd(name: .cacheControl, value: SSEConstants.cacheControl)
        response.headers.replaceOrAdd(name: .connection, value: SSEConstants.connection)
        response.headers.replaceOrAdd(name: "X-Accel-Buffering", value: SSEConstants.noBuffering)

        return response
    }

    /// Reads the identity an earlier middleware established, yielding `.anonymous` if there is
    /// none. SSE routes never reject on their own — the handler decides.
    static func buildContext(from request: Request) -> ServiceContext {
        if let userId = request.auth.get(AuthenticatedUser.self)?.id {
            return .authenticated(userId: userId)
        }
        return .anonymous
    }

    /// Decodes a request body as JSON with ISO 8601 dates and key names taken as written.
    static func decodeBody<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try request.content.decode(type, using: decoder)
    }
}
