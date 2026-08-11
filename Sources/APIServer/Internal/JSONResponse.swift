import Foundation
internal import Vapor

/// The single place an `Encodable` becomes a JSON response.
///
/// The same four lines — encode, set the content type, build the response — had been copied to
/// sixteen route-registration sites, two of them identical private methods on the same type. There
/// is one reason to change the encoder configuration or the headers, so there is one place to
/// change them.
func encodeJSONResponse<T: Encodable>(_ value: T) throws -> Vapor.Response {
    let data = try JSONEncoder.apiDefault.encode(value)
    var headers = HTTPHeaders()
    headers.contentType = .json
    return Vapor.Response(status: .ok, headers: headers, body: .init(data: data))
}
