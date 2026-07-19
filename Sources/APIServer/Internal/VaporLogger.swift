import Foundation
internal import Vapor
import APIContract

struct VaporLogger: ServerLogger {
    let logger: Logger

    func trace(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.trace("\(message())", file: file, function: function, line: line)
    }

    func debug(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.debug("\(message())", file: file, function: function, line: line)
    }

    func info(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.info("\(message())", file: file, function: function, line: line)
    }

    func notice(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.notice("\(message())", file: file, function: function, line: line)
    }

    func warning(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.warning("\(message())", file: file, function: function, line: line)
    }

    func error(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.error("\(message())", file: file, function: function, line: line)
    }

    func critical(_ message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        logger.critical("\(message())", file: file, function: function, line: line)
    }
}

