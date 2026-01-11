import Foundation

/// ストリームレスポンス - SSE/WebSocket等のストリーミング
///
/// 複数のイベントを順次送信するストリーミングレスポンス。
/// Server-Sent Events (SSE) やチャンク転送などに使用。
///
/// ## 設計思想
/// - イベント型をAssociated Typeで明示し型安全性を確保
/// - AsyncStream/AsyncSequenceベースで非同期ストリーミング
/// - 具体的なフォーマット（SSE等）は実装クラスに委譲
public protocol StreamResponse: ServerResponse {
    /// ストリームで送信されるイベント型
    associatedtype Event: Sendable

    /// イベントストリーム
    var eventStream: AsyncStream<Event> { get }
}

// MARK: - SSE Response

/// Server-Sent Events (SSE) レスポンス
///
/// WHATWG SSE仕様に準拠したストリーミングレスポンス。
/// イベントは自動的にSSE形式にフォーマットされる。
///
/// ## 使用例
/// ```swift
/// let stream = AsyncStream<MyEvent> { continuation in
///     continuation.yield(.progress(0.5))
///     continuation.yield(.complete)
///     continuation.finish()
/// }
/// return SSEStreamResponse(events: stream, eventTypeMapper: { $0.eventName })
/// ```
public struct SSEStreamResponse<Event: Encodable & Sendable>: StreamResponse, HeaderModifiableResponse {
    public let status: HTTPStatus
    public let headers: [String: String]
    public let eventStream: AsyncStream<Event>

    /// イベントからSSEイベントタイプを取得するマッパー
    public let eventTypeMapper: @Sendable (Event) -> String?

    /// 標準のSSEレスポンスを作成
    ///
    /// - Parameters:
    ///   - events: イベントストリーム
    ///   - eventTypeMapper: イベントからSSEイベントタイプを取得するクロージャ
    public init(
        events: AsyncStream<Event>,
        eventTypeMapper: @escaping @Sendable (Event) -> String? = { _ in nil }
    ) {
        self.status = .ok
        self.headers = SSEConstants.defaultHeaders
        self.eventStream = events
        self.eventTypeMapper = eventTypeMapper
    }

    /// カスタムヘッダー付きSSEレスポンスを作成
    public init(
        status: HTTPStatus = .ok,
        headers: [String: String],
        events: AsyncStream<Event>,
        eventTypeMapper: @escaping @Sendable (Event) -> String? = { _ in nil }
    ) {
        self.status = status
        // SSE必須ヘッダーとカスタムヘッダーをマージ
        var mergedHeaders = SSEConstants.defaultHeaders
        for (key, value) in headers {
            mergedHeaders[key] = value
        }
        self.headers = mergedHeaders
        self.eventStream = events
        self.eventTypeMapper = eventTypeMapper
    }

    /// ヘッダーを追加したレスポンスを返す
    public func withAddedHeaders(_ additionalHeaders: [String: String]) -> SSEStreamResponse<Event> {
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

/// 型消去されたストリームレスポンス
///
/// ミドルウェアでストリームレスポンスを統一的に扱うための型。
/// 内部でVaporの具体的なResponse型を保持し、変換を防ぐ。
///
/// - Note: `underlyingResponse`はVaporのResponseクラス（Sendable準拠）を保持するため、
///   @unchecked Sendableで安全に扱える。
public struct AnyStreamResponse: ServerResponse, @unchecked Sendable {
    public let status: HTTPStatus
    public let headers: [String: String]

    /// 内部で保持する元のレスポンス（Vapor Response等）
    internal let underlyingResponse: Any

    public init<R: ServerResponse>(wrapping response: R, underlying: Any) {
        self.status = response.status
        self.headers = response.headers
        self.underlyingResponse = underlying
    }
}
