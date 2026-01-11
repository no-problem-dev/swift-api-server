import Foundation

/// サーバーレスポンスの基底プロトコル
///
/// 全てのレスポンス型が共有する最小限のインターフェース。
/// 具象的なレスポンス種別は`DataResponse`または`StreamResponse`を使用。
///
/// ## 設計思想
/// - Boolean フラグ (`isStreaming`) ではなく型で区別
/// - 各レスポンス種別が適切なプロパティを持つ
/// - ミドルウェアは existential として扱い、必要に応じてダウンキャスト
public protocol ServerResponse: Sendable {
    /// HTTPステータス
    var status: HTTPStatus { get }

    /// HTTPヘッダー
    var headers: [String: String] { get }
}

// MARK: - Response Header Addition

/// ヘッダー追加をサポートするレスポンス
///
/// DataResponse と一部の StreamResponse 実装がこれに準拠。
public protocol HeaderModifiableResponse: ServerResponse {
    /// ヘッダーを追加したレスポンスを返す
    func withAddedHeaders(_ headers: [String: String]) -> Self
}
