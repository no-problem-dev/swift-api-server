/// サーバーログ出力プロトコル
public protocol ServerLogger: Sendable {
    func trace(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func debug(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func info(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func notice(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func warning(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func error(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
    func critical(_ message: @autoclosure () -> String, file: String, function: String, line: UInt)
}

// MARK: - Default Parameter Extensions

extension ServerLogger {
    public func trace(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        trace(message(), file: file, function: function, line: line)
    }

    public func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        debug(message(), file: file, function: function, line: line)
    }

    public func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        info(message(), file: file, function: function, line: line)
    }

    public func notice(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        notice(message(), file: file, function: function, line: line)
    }

    public func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        warning(message(), file: file, function: function, line: line)
    }

    public func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        error(message(), file: file, function: function, line: line)
    }

    public func critical(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        critical(message(), file: file, function: function, line: line)
    }
}
