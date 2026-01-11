import Foundation

/// Server-Sent Event
///
/// WHATWG Server-Sent Events仕様に準拠したイベント型。
/// https://html.spec.whatwg.org/multipage/server-sent-events.html
///
/// ## 使用例
/// ```swift
/// // データのみ
/// let event = SSEEvent(data: "Hello, World!")
///
/// // イベント名付き
/// let event = SSEEvent(data: jsonString, event: "progress")
///
/// // 完全なイベント
/// let event = SSEEvent(
///     data: jsonString,
///     event: "update",
///     id: "msg-123",
///     retry: 3000
/// )
/// ```
public struct SSEEvent: Sendable, Hashable {
    /// イベントデータ
    ///
    /// 複数行のデータも対応（各行が `data:` フィールドとして送信されます）
    public let data: String?

    /// イベントタイプ（オプション）
    ///
    /// クライアント側で `addEventListener(type, handler)` でリスンする際のイベント名
    public let event: String?

    /// イベントID（オプション）
    ///
    /// クライアントが再接続時に `Last-Event-ID` ヘッダーで送信する識別子
    public let id: String?

    /// 再接続時間（ミリ秒、オプション）
    ///
    /// クライアントの再接続間隔を指定
    public let retry: Int?

    /// イニシャライザ
    ///
    /// - Parameters:
    ///   - data: イベントデータ
    ///   - event: イベントタイプ（デフォルト: nil）
    ///   - id: イベントID（デフォルト: nil）
    ///   - retry: 再接続時間（ミリ秒、デフォルト: nil）
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

    /// Encodableな値からイベントを作成
    ///
    /// - Parameters:
    ///   - value: JSONエンコード可能な値
    ///   - event: イベントタイプ（オプション）
    ///   - id: イベントID（オプション）
    ///   - encoder: JSONEncoder（デフォルト: 標準設定）
    /// - Returns: SSEEvent
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

    /// コメントイベントを作成（キープアライブ用）
    ///
    /// - Parameter comment: コメントテキスト
    /// - Returns: コメントとして送信されるイベント
    public static func comment(_ comment: String) -> SSEEvent {
        SSEEvent(data: nil, event: nil, id: nil, retry: nil, comment: comment)
    }

    /// SSE形式の文字列に変換
    ///
    /// - Returns: SSE仕様に準拠したフォーマット済み文字列
    public func formatted() -> String {
        var lines: [String] = []

        // イベントタイプ
        if let event = event {
            lines.append("event: \(event)")
        }

        // ID
        if let id = id {
            lines.append("id: \(id)")
        }

        // 再接続時間
        if let retry = retry {
            lines.append("retry: \(retry)")
        }

        // データ（複数行対応）
        if let data = data {
            for line in data.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("data: \(line)")
            }
        }

        // コメント
        if let comment = _comment {
            lines.append(": \(comment)")
        }

        // 空のイベントでも終端は必要
        if lines.isEmpty {
            return "\n"
        }

        return lines.joined(separator: "\n") + "\n\n"
    }

    // MARK: - Internal

    /// コメント（内部用）
    private let _comment: String?

    /// コメント付きイニシャライザ（内部用）
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

/// SSEエンコーディングエラー
public enum SSEEncodingError: Error, LocalizedError {
    /// 無効なUTF-8エンコーディング
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Failed to encode value as UTF-8 string"
        }
    }
}

// MARK: - SSE Constants

/// SSE関連の定数
public enum SSEConstants {
    /// SSEのContent-Type
    public static let contentType = "text/event-stream"

    /// キャッシュ無効化ヘッダー値
    public static let cacheControl = "no-cache"

    /// 接続維持ヘッダー値
    public static let connection = "keep-alive"

    /// バッファリング無効化（nginx等）
    public static let noBuffering = "no"

    /// デフォルト再接続時間（ミリ秒）
    public static let defaultRetry = 3000

    /// SSEレスポンス用のデフォルトヘッダー
    public static let defaultHeaders: [String: String] = [
        "Content-Type": contentType,
        "Cache-Control": cacheControl,
        "Connection": connection,
        "X-Accel-Buffering": noBuffering
    ]
}
