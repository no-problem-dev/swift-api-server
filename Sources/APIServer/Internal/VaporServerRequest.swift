import Foundation
internal import Vapor
import APIContract

struct VaporServerRequest: ServerRequest {
    let request: Request

    var pathParameters: [String: String] {
        // Vaporのパラメータは動的に取得する必要があるため、
        // 実際にはルート登録時に設定される
        [:]
    }

    var queryParameters: [String: String] {
        var params: [String: String] = [:]
        if let queryString = request.url.query {
            for item in queryString.split(separator: "&") {
                let parts = item.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                    let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    params[key] = value
                }
            }
        }
        return params
    }

    var headers: [String: String] {
        var result: [String: String] = [:]
        for (name, value) in request.headers {
            result[name] = value
        }
        return result
    }

    var body: Data? {
        guard let buffer = request.body.data else { return nil }
        return Data(buffer: buffer)
    }

    var url: URL {
        URL(string: request.url.string) ?? URL(string: "/")!
    }

    var method: String {
        request.method.rawValue
    }

    var authenticatedUserId: String? {
        request.auth.get(AuthenticatedUser.self)?.id
    }
}

