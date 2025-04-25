import Foundation
import os

@available(iOS 14.0, *)
final class Logger {
    static let shared = Logger()
    private let logger: os.Logger

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "CourseApp"
        logger = os.Logger(subsystem: subsystem, category: "App")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

/// Fallback for iOS < 14
final class LegacyLogger {
    static let shared = LegacyLogger()
    func info(_ message: String)  { print("INFO:  \(message)") }
    func debug(_ message: String) { print("DEBUG: \(message)") }
    func error(_ message: String) { print("ERROR: \(message)") }
}
