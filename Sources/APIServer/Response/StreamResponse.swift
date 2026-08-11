import Foundation

/// A response whose body is produced over time, one event at a time.
///
/// The element type is an associated type rather than an existential, so the body stays typed all
/// the way from the producer to the point where it is serialized. Events are delivered in the
/// order the stream yields them.
public protocol StreamResponse: ServerResponse {
    /// The type of value the stream carries.
    associatedtype Event: Sendable

    /// The events to send, in order, until the stream finishes.
    ///
    /// A single-consumer stream: iterating it more than once yields nothing the second time.
    var eventStream: AsyncStream<Event> { get }
}

// MARK: - SSE Response

/// A Server-Sent Events body built from a stream of encodable values.
///
/// - Important: This type is not wired into route registration. The `sse` and `ssePost` route
///   families take an `AsyncSequence` of `SSEEvent` directly and serialize it themselves, and a
///   value of this type returned from a middleware reaches the client as headers with an empty
///   body — its events are never written. Use the route helpers to serve SSE.
///
/// ## Example
/// ```swift
/// let stream = AsyncStream<MyEvent> { continuation in
///     continuation.yield(.progress(0.5))
///     continuation.yield(.complete)
///     continuation.finish()
/// }
/// return SSEStreamResponse(events: stream, eventTypeMapper: { $0.eventName })
/// ```
public struct SSEStreamResponse<Event: Encodable & Sendable>: StreamResponse {
    public let status: HTTPStatus
    public let headers: [String: String]
    public let eventStream: AsyncStream<Event>

    /// Supplies the SSE `event` field name for a value, or `nil` to omit the field.
    public let eventTypeMapper: @Sendable (Event) -> String?

    /// Creates a `200 OK` response carrying the SSE headers.
    ///
    /// - Parameters:
    ///   - events: The events to send, in order.
    ///   - eventTypeMapper: Names each event's SSE type; omits the field by default.
    public init(
        events: AsyncStream<Event>,
        eventTypeMapper: @escaping @Sendable (Event) -> String? = { _ in nil }
    ) {
        self.status = .ok
        self.headers = SSEConstants.defaultHeaders
        self.eventStream = events
        self.eventTypeMapper = eventTypeMapper
    }

    /// Creates a response with extra headers alongside the SSE defaults.
    ///
    /// The SSE headers are applied first, so passing `Content-Type` or `Cache-Control` here
    /// overrides them.
    ///
    /// - Parameters:
    ///   - status: The status to send; `.ok` by default.
    ///   - headers: Headers to add on top of the SSE defaults.
    ///   - events: The events to send, in order.
    ///   - eventTypeMapper: Names each event's SSE type; omits the field by default.
    public init(
        status: HTTPStatus = .ok,
        headers: [String: String],
        events: AsyncStream<Event>,
        eventTypeMapper: @escaping @Sendable (Event) -> String? = { _ in nil }
    ) {
        self.status = status
        var mergedHeaders = SSEConstants.defaultHeaders
        for (key, value) in headers {
            mergedHeaders[key] = value
        }
        self.headers = mergedHeaders
        self.eventStream = events
        self.eventTypeMapper = eventTypeMapper
    }

    /// Returns a copy carrying the given headers, replacing any of the same name.
    ///
    /// The copy shares the same stream, so only one of the two values can be consumed.
    public func addingHeaders(_ additionalHeaders: [String: String]) -> SSEStreamResponse<Event> {
        var newHeaders = headers
        for (key, value) in additionalHeaders {
            newHeaders[key] = value
        }
        return SSEStreamResponse(
            status: status,
            headers: newHeaders,
            events: eventStream,
            eventTypeMapper: eventTypeMapper
        )
    }
}

// MARK: - Type-Erased Stream Response

/// Carries a framework response through middleware without converting it.
///
/// Status and headers are snapshotted so middleware can read and extend them, while the object
/// that actually gets written stays untouched inside `underlyingResponse` — converting it would
/// buffer the stream. The adapter copies the snapshot's headers onto the underlying object before
/// sending, which is why a header added here is not lost.
///
/// `@unchecked Sendable` is sound because the value the wrapper is given is itself `Sendable`;
/// the property is typed `Any` only to avoid naming a framework type in this file.
struct AnyStreamResponse: ServerResponse, @unchecked Sendable {
    let status: HTTPStatus
    let headers: [String: String]

    /// The object that will actually be written, kept as-is.
    let underlyingResponse: Any

    /// Wraps a response for transport through the middleware chain.
    ///
    /// - Parameters:
    ///   - response: Supplies the status and headers to snapshot.
    ///   - underlying: The framework-specific object to send unchanged.
    init<R: ServerResponse>(wrapping response: R, underlying: Any) {
        self.status = response.status
        self.headers = response.headers
        self.underlyingResponse = underlying
    }

    private init(status: HTTPStatus, headers: [String: String], underlying: Any) {
        self.status = status
        self.headers = headers
        self.underlyingResponse = underlying
    }

    func addingHeaders(_ additionalHeaders: [String: String]) -> AnyStreamResponse {
        AnyStreamResponse(
            status: status,
            headers: headers.merging(additionalHeaders) { _, new in new },
            underlying: underlyingResponse
        )
    }
}
