import Foundation

/// The deployment mode a server runs in, decided once at creation and never re-read afterwards.
public enum ServerEnvironment: String, Sendable {
    case development
    case testing
    case production

    /// Reads the environment from the process environment.
    ///
    /// `SWIFT_ENV` wins over `VAPOR_ENV`. The value is lowercased before matching, and anything
    /// unrecognized — including both variables being unset — falls back to `.development`,
    /// so a typo in the variable silently yields a development server.
    public static func detect() -> ServerEnvironment {
        if let env = ProcessInfo.processInfo.environment["SWIFT_ENV"] ??
                     ProcessInfo.processInfo.environment["VAPOR_ENV"] {
            return ServerEnvironment(rawValue: env.lowercased()) ?? .development
        }
        return .development
    }

    /// Whether this is `.development`.
    public var isDevelopment: Bool { self == .development }

    /// Whether this is `.testing`.
    public var isTesting: Bool { self == .testing }

    /// Whether this is `.production`.
    public var isProduction: Bool { self == .production }

    /// Reads an arbitrary environment variable of the current process.
    ///
    /// - Parameter key: The variable name.
    /// - Returns: The value, or `nil` when the variable is unset.
    public static func get(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}
