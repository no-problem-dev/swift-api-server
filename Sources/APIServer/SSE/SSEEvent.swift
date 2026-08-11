import Foundation

/// One event in a Server-Sent Events stream, as defined by the WHATWG HTML Standard.
///
/// Every field is optional because the format allows it: an event with nothing set serializes to a
/// blank line, which browsers read as a heartbeat.
///
/// ## Example
/// ```swift
/// // Data only
/// let event = SSEEvent(data: "Hello, World!")
///
/// // With a type the client can listen for
/// let event = SSEEvent(data: jsonString, event: "progress")
///
/// // Every field
/// let event = SSEEvent(
///     data: jsonString,
///     event: "update",
///     id: "msg-123",
///     retry: 3000
/// )
/// ```
public struct SSEEvent: Sendable, Hashable {
    /// The payload. Newlines are permitted and become one `data:` line each, which the client
    /// rejoins with newlines.
    public let data: String?

    /// The event name clients listen for with `addEventListener(type:)`. Without it, an event
    /// arrives at the default `message` handler.
    public let event: String?

    /// The identifier a client echoes in `Last-Event-ID` when it reconnects, letting a server
    /// resume where the connection dropped.
    public let id: String?

    /// The delay in milliseconds a client should wait before reconnecting. It persists on the
    /// client, so sending it once changes the interval for the rest of the stream.
    public let retry: Int?

    /// Creates an event.
    ///
    /// - Parameters:
    ///   - data: The payload; may span multiple lines.
    ///   - event: The event name clients can listen for.
    ///   - id: The identifier for resuming after a reconnect.
    ///   - retry: The reconnection delay in milliseconds.
    public init(
        data: String? = nil,
        event: String? = nil,
        id: String? = nil,
        retry: Int? = nil
    ) {
        self.data = data
        self.event = event
        self.id = id
        self.retry = retry
        self._comment = nil
    }

    /// Creates an event whose data is the JSON encoding of a value.
    ///
    /// The encoder defaults to a plain `JSONEncoder`, not the package's ISO 8601 one — pass
    /// `.apiDefault` to match how the rest of the package writes dates.
    ///
    /// - Parameters:
    ///   - value: The value to encode into `data`.
    ///   - event: The event name clients can listen for.
    ///   - id: The identifier for resuming after a reconnect.
    ///   - encoder: The encoder to use.
    /// - Throws: `SSEEncodingError.invalidUTF8` if the encoded bytes are not valid UTF-8, plus
    ///   whatever `encoder` throws.
    public static func json<T: Encodable>(
        _ value: T,
        event: String? = nil,
        id: String? = nil,
        encoder: JSONEncoder = .init()
    ) throws -> SSEEvent {
        let data = try encoder.encode(value)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SSEEncodingError.invalidUTF8
        }
        return SSEEvent(data: jsonString, event: event, id: id)
    }

    /// Creates a comment, which clients ignore — the usual way to keep an idle connection open
    /// through proxies that close it.
    ///
    /// - Parameter comment: The text after the leading colon. Keep it on one line; embedded
    ///   newlines are written verbatim and break the framing.
    public static func comment(_ comment: String) -> SSEEvent {
        SSEEvent(data: nil, event: nil, id: nil, retry: nil, comment: comment)
    }

    /// Serializes the event to wire format, terminated by the blank line that dispatches it.
    ///
    /// Fields are emitted in a fixed order — `event`, `id`, `retry`, `data`, comment — and an
    /// event with no fields at all becomes a lone newline.
    ///
    /// - Returns: The bytes to write, as a UTF-8 string.
    public func formatted() -> String {
        var lines: [String] = []

        if let event = event {
            lines.append("event: \(event)")
        }

        if let id = id {
            lines.append("id: \(id)")
        }

        if let retry = retry {
            lines.append("retry: \(retry)")
        }

        // Each line of a multi-line payload becomes its own `data:` field; the client rejoins them.
        if let data = data {
            for line in data.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("data: \(line)")
            }
        }

        if let comment = _comment {
            lines.append(": \(comment)")
        }

        if lines.isEmpty {
            return "\n"
        }

        return lines.joined(separator: "\n") + "\n\n"
    }

    // MARK: - Internal

    private let _comment: String?

    private init(
        data: String?,
        event: String?,
        id: String?,
        retry: Int?,
        comment: String?
    ) {
        self.data = data
        self.event = event
        self.id = id
        self.retry = retry
        self._comment = comment
    }
}


// MARK: - Errors

/// A failure while turning a value into an event payload.
public enum SSEEncodingError: Error, LocalizedError {
    /// The encoded bytes were not valid UTF-8, so they cannot be sent as event data.
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Failed to encode value as UTF-8 string"
        }
    }
}

// MARK: - SSE Constants

/// The header values an SSE response has to send.
public enum SSEConstants {
    /// The media type that makes a client treat the body as an event stream.
    public static let contentType = "text/event-stream"

    /// Keeps intermediaries from serving a cached copy of a stream that never repeats.
    public static let cacheControl = "no-cache"

    /// Keeps the connection open for the life of the stream.
    public static let connection = "keep-alive"

    /// Value for `X-Accel-Buffering`. Without it, nginx and similar proxies buffer the whole
    /// response and events arrive only when the stream ends.
    public static let noBuffering = "no"

    /// A reasonable reconnection delay in milliseconds, for callers that want to send `retry`.
    /// Not applied automatically.
    public static let defaultRetry = 3000

    /// The four headers above, ready to apply to a response.
    public static let defaultHeaders: [String: String] = [
        "Content-Type": contentType,
        "Cache-Control": cacheControl,
        "Connection": connection,
        "X-Accel-Buffering": noBuffering
    ]
}
