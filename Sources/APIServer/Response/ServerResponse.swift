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

    /// ヘッダーを追加したレスポンスを返す。同名ヘッダーは引数側で置き換える。
    ///
    /// ミドルウェア（CORS・セキュリティヘッダー等）が使う。**全てのレスポンス型が
    /// 実装しなければならない。** 以前は `HeaderModifiableResponse` という別プロトコルで
    /// 任意適合にし、未適合の型には黙って元のレスポンスを返していたが、それだと
    /// ストリームレスポンスに対して CORS ヘッダーが無言で落ちた。実装漏れが
    /// コンパイルエラーになるよう基底プロトコルの要件にしている。
    func addingHeaders(_ headers: [String: String]) -> Self
}
