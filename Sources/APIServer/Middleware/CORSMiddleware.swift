import APIContract
import Foundation

/// Answers CORS preflights and attaches the access-control headers to every other response.
///
/// A request whose method is `OPTIONS` is answered here with `204 No Content` and never reaches a
/// route handler, so an endpoint cannot implement `OPTIONS` while this middleware is installed.
/// All other responses — buffered and streaming alike — pass through and gain the headers.
///
/// Register it first: headers are added on the way out, and a middleware that short-circuits
/// earlier in the chain will produce a response this one never sees.
public struct CORSServerMiddleware: ServerMiddleware {
    private let configuration: CORSConfiguration

    /// Creates the middleware.
    ///
    /// - Parameter configuration: The policy to apply; permits every origin by default.
    public init(configuration: CORSConfiguration = .default()) {
        self.configuration = configuration
    }

    public func handle(
        request: any ServerRequest,
        next: @escaping @Sendable () async throws -> any ServerResponse
    ) async throws -> any ServerResponse {
        if request.method == "OPTIONS" {
            return BasicDataResponse(
                status: .noContent,
                headers: corsHeaders(for: request, extending: nil)
            )
        }

        let response = try await next()

        return response.addingHeaders(
            corsHeaders(for: request, extending: response.headers["Vary"])
        )
    }

    /// - Parameter existingVary: The `Vary` the response already carries, so `Origin` is added to
    ///   it rather than replacing it.
    private func corsHeaders(
        for request: any ServerRequest,
        extending existingVary: String?
    ) -> HTTPHeaderFields {
        var headers = HTTPHeaderFields()

        // An allowed origin is echoed back rather than answered with `*`, which is what makes
        // credentialed requests work.
        if let origin = request.headers["Origin"] {
            if configuration.allowedOrigins.contains("*") ||
               configuration.allowedOrigins.contains(origin) {
                headers["Access-Control-Allow-Origin"] = origin
            }
        } else if configuration.allowedOrigins.contains("*") {
            headers["Access-Control-Allow-Origin"] = "*"
        }

        // What this response allows depends on the origin that asked, so a shared cache must not
        // serve it to a different one. Without this, a cache hands an origin the allow header that
        // the allow-list refused it.
        headers["Vary"] = Self.vary(byOriginExtending: existingVary)

        headers["Access-Control-Allow-Methods"] = configuration.allowedMethods
            .map { $0.rawValue }
            .joined(separator: ", ")

        if !configuration.allowedHeaders.isEmpty {
            headers["Access-Control-Allow-Headers"] = configuration.allowedHeaders.joined(separator: ", ")
        }

        if configuration.allowCredentials {
            headers["Access-Control-Allow-Credentials"] = "true"
        }

        if let maxAge = configuration.maxAge {
            headers["Access-Control-Max-Age"] = String(maxAge)
        }

        if !configuration.exposedHeaders.isEmpty {
            headers["Access-Control-Expose-Headers"] = configuration.exposedHeaders.joined(separator: ", ")
        }

        return headers
    }

    /// Adds `Origin` to a `Vary` value, keeping what the handler already varies by.
    ///
    /// A list that already names `Origin`, or the `*` that stands for every field, is returned
    /// untouched rather than gaining a duplicate.
    private static func vary(byOriginExtending existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Origin"
        }

        let fields = existing
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let alreadyVaries = fields.contains {
            $0 == "*" || $0.caseInsensitiveCompare("Origin") == .orderedSame
        }

        return alreadyVaries ? existing : "\(existing), Origin"
    }
}

/// The access-control policy `CORSServerMiddleware` applies.
///
/// The default value permits every origin, which is convenient in development and rarely what a
/// deployed service wants.
public struct CORSConfiguration: Sendable {
    /// Origins allowed to read responses. The single entry `"*"` permits all of them.
    ///
    /// Matching is exact — there is no wildcard within an entry, so `https://*.example.com` never
    /// matches anything.
    public let allowedOrigins: [String]

    /// Methods advertised in the preflight answer. This list is advertisement only; it does not
    /// stop a request whose method is absent from it.
    public let allowedMethods: [APIMethod]

    /// Request headers a browser may send. Omitted from the response entirely when empty.
    public let allowedHeaders: [String]

    /// Response headers a browser may read beyond the CORS-safelisted ones. Omitted when empty.
    public let exposedHeaders: [String]

    /// Whether browsers may attach cookies and `Authorization` to cross-origin requests.
    public let allowCredentials: Bool

    /// How long, in seconds, a browser may cache the preflight answer. `nil` omits the header.
    public let maxAge: Int?

    /// Creates a policy from its parts.
    ///
    /// - Parameters:
    ///   - allowedOrigins: Origins allowed to read responses; `["*"]` for all.
    ///   - allowedMethods: Methods to advertise in preflight answers.
    ///   - allowedHeaders: Request headers a browser may send.
    ///   - exposedHeaders: Response headers a browser may read.
    ///   - allowCredentials: Whether credentials may accompany cross-origin requests.
    ///   - maxAge: Preflight cache lifetime in seconds; `nil` omits the header.
    public init(
        allowedOrigins: [String] = ["*"],
        allowedMethods: [APIMethod] = [.get, .post, .put, .patch, .delete, .options],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"],
        exposedHeaders: [String] = [],
        allowCredentials: Bool = false,
        maxAge: Int? = 600
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.allowCredentials = allowCredentials
        self.maxAge = maxAge
    }

    /// A policy that permits every origin and caches preflights for ten minutes.
    public static func `default`() -> CORSConfiguration {
        CORSConfiguration()
    }

    /// Creates a policy from the four settings a deployed service usually needs to change,
    /// leaving `exposedHeaders` empty and `maxAge` at its default.
    ///
    /// - Parameters:
    ///   - allowedOrigins: Origins allowed to read responses, such as `["https://example.com"]`.
    ///   - allowedMethods: Methods to advertise in preflight answers.
    ///   - allowedHeaders: Request headers a browser may send.
    ///   - allowCredentials: Whether credentials may accompany cross-origin requests. Browsers
    ///     reject a credentialed response whose allowed origin is `*`; nothing here rejects that
    ///     combination, and because an allowed origin is echoed back verbatim, passing `["*"]`
    ///     with credentials enabled works in practice and effectively trusts every origin.
    /// - Returns: The policy.
    public static func custom(
        allowedOrigins: [String],
        allowedMethods: [APIMethod] = [.get, .post, .put, .patch, .delete, .options],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"],
        allowCredentials: Bool = false
    ) -> CORSConfiguration {
        CORSConfiguration(
            allowedOrigins: allowedOrigins,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            allowCredentials: allowCredentials
        )
    }
}
