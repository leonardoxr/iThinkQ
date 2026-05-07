import Foundation
import OSLog

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.xavier.thinkq"

    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let control = Logger(subsystem: subsystem, category: "Control")
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")
    static let windowing = Logger(subsystem: subsystem, category: "Windowing")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
    static let rateLimit = Logger(subsystem: subsystem, category: "RateLimit")
}
