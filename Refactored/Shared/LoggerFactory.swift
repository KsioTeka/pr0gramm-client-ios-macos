import Foundation
import os

// MARK: - Logger Factory
enum LoggerFactory {
    static func create<T>(for type: T.Type, category: String? = nil) -> Logger {
        let categoryName = category ?? String(describing: type)
        return Logger(subsystem: Bundle.main.bundleIdentifier!, category: categoryName)
    }
    
    static func create(category: String) -> Logger {
        return Logger(subsystem: Bundle.main.bundleIdentifier!, category: category)
    }
}

// MARK: - Logger Protocol
protocol LoggerProtocol {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func trace(_ message: String)
}

// MARK: - OS Logger Extension
extension Logger: LoggerProtocol {
    func trace(_ message: String) {
        debug("\(message)")
    }
}

// MARK: - Mock Logger for Testing
#if DEBUG
class MockLogger: LoggerProtocol {
    func debug(_ message: String) {
        print("[DEBUG] \(message)")
    }
    
    func info(_ message: String) {
        print("[INFO] \(message)")
    }
    
    func warning(_ message: String) {
        print("[WARNING] \(message)")
    }
    
    func error(_ message: String) {
        print("[ERROR] \(message)")
    }
    
    func trace(_ message: String) {
        print("[TRACE] \(message)")
    }
}
#endif