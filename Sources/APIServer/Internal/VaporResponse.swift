import Foundation
internal import Vapor
import APIContract

/// Vapor ResponseをServerResponseとしてラップ
///
/// ミドルウェアがVaporのResponseを直接操作できるようにしつつ、
/// 抽象インターフェースを提供する。ストリーミングレスポンスにも対応。
struct VaporResponse: ServerResponse {
    let response: Response

    var status: HTTPStatus {
        HTTPStatus(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase)
    }

    var headers: [String: String] {
        var result: [String: String] = [:]
        for (name, value) in response.headers {
            result[name] = value
        }
        return result
    }

    /// ヘッダーを追加したレスポンスを返す
    ///
    /// VaporのResponseはクラスなので、直接ヘッダーを変更できます。
    /// ストリーミングボディを保持したまま、ヘッダーを追加します。
    func addingHeaders(_ additionalHeaders: [String: String]) -> VaporResponse {
        for (key, value) in additionalHeaders {
            response.headers.replaceOrAdd(name: HTTPHeaders.Name(key), value: value)
        }
        return self
    }
}
