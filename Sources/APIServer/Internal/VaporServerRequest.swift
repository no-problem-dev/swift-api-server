import Foundation
internal import Vapor
import APIContract

struct VaporServerRequest: ServerRequest {
    let request: Request

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

    var headers: HTTPHeaderFields {
        HTTPHeaderFields(from: request.headers)
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

