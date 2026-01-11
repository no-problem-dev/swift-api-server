import Foundation
internal import Vapor
import APIContract

/// Vapor依存のSSEレスポンス構築ヘルパー
///
/// SSERoutesの各拡張で重複していたbuildSSEResponse/buildContextを統合。
/// Internal実装としてVapor依存を隠蔽。
enum VaporSSEBuilder {
    /// SSEレスポンスを構築
    ///
    /// Swift Forums推奨パターン: bodyを先に作成 → Responseコンストラクタに渡す → ヘッダー設定
    /// https://forums.swift.org/t/re-stream-chunked-data-server-sent-events-from-another-web-service-through-the-vapor-endpoint/65375
    static func buildSSEResponse<S: AsyncSequence & Sendable>(
        from stream: S,
        request: Request
    ) -> Response where S.Element == SSEEvent {
        // Step 1: bodyを先に作成
        let body = Response.Body(stream: { writer in
            Task {
                do {
                    // 接続確立のための初期コメント送信
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

        // Step 2: Responseをbodyと一緒に作成
        let response = Response(status: .ok, body: body)

        // Step 3: ヘッダーを後から設定
        response.headers.replaceOrAdd(name: .contentType, value: SSEConstants.contentType)
        response.headers.replaceOrAdd(name: .cacheControl, value: SSEConstants.cacheControl)
        response.headers.replaceOrAdd(name: .connection, value: SSEConstants.connection)
        response.headers.replaceOrAdd(name: "X-Accel-Buffering", value: SSEConstants.noBuffering)

        return response
    }

    /// リクエストからServiceContextを構築
    static func buildContext(from request: Request) -> ServiceContext {
        if let userId = request.auth.get(AuthenticatedUser.self)?.id {
            return .authenticated(userId: userId)
        }
        return .anonymous
    }

    /// リクエストボディをデコード
    static func decodeBody<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try request.content.decode(type, using: decoder)
    }
}
