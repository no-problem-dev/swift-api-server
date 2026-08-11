internal import Vapor

extension HTTPHeaderFields {
    /// Reads the framework's headers into the abstract set.
    init(from vaporHeaders: HTTPHeaders) {
        var fields: [String: String] = [:]
        for (name, value) in vaporHeaders {
            fields[name] = value
        }
        self.init(fields)
    }
}
