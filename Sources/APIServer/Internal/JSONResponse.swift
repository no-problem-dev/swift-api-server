import Foundation
internal import Vapor

/// `Encodable` を JSON ボディの `Vapor.Response` にする唯一の変換点。
///
/// 同じ「エンコード → Content-Type 付与 → Response 生成」の 4 行が、ルート登録の各所に
/// 16 箇所複製されていた（`VaporServerApplication` には同一実装の private メソッドが
/// static / instance の 2 つ並存していた）。エンコーダ設定やヘッダを変える理由は 1 つなので、
/// 変更点も 1 つにまとめる。
func encodeJSONResponse<T: Encodable>(_ value: T) throws -> Vapor.Response {
    let data = try JSONEncoder.apiDefault.encode(value)
    var headers = HTTPHeaders()
    headers.contentType = .json
    return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
}
