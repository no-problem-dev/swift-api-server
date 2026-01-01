/// サーバー実行環境
public enum ServerEnvironment: String, Sendable {
    case development
    case testing
    case production

    /// 環境変数から実行環境を検出
    ///
    /// `SWIFT_ENV` または `VAPOR_ENV` 環境変数を参照し、
    /// 設定がない場合は `.development` を返します。
    public static func detect() -> ServerEnvironment {
        if let env = ProcessInfo.processInfo.environment["SWIFT_ENV"] ??
                     ProcessInfo.processInfo.environment["VAPOR_ENV"] {
            return ServerEnvironment(rawValue: env.lowercased()) ?? .development
        }
        return .development
    }

    /// 開発環境かどうか
    public var isDevelopment: Bool { self == .development }

    /// テスト環境かどうか
    public var isTesting: Bool { self == .testing }

    /// 本番環境かどうか
    public var isProduction: Bool { self == .production }

    /// 環境変数を取得
    ///
    /// - Parameter key: 環境変数のキー
    /// - Returns: 環境変数の値、存在しない場合は nil
    public static func get(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}

import Foundation
