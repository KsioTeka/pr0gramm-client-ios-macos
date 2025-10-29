import Foundation

// MARK: - State of the Art Error Handling

// MARK: - Simplified Error Types
enum APIError: Error, LocalizedError {
    case networkFailure
    case invalidResponse
    case serverError(Int)
    case authenticationRequired
    case decodingError
    case rateLimited
    case maintenanceMode
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "Netzwerkfehler - Bitte prüfe deine Internetverbindung"
        case .invalidResponse:
            return "Ungültige Serverantwort"
        case .serverError(let code):
            return "Serverfehler: \(code)"
        case .authenticationRequired:
            return "Anmeldung erforderlich"
        case .decodingError:
            return "Datenverarbeitungsfehler"
        case .rateLimited:
            return "Zu viele Anfragen - Bitte warte einen Moment"
        case .maintenanceMode:
            return "Server wird gewartet - Bitte versuche es später erneut"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkFailure:
            return "Prüfe deine Internetverbindung und versuche es erneut"
        case .authenticationRequired:
            return "Bitte melde dich erneut an"
        case .rateLimited:
            return "Warte 30 Sekunden und versuche es erneut"
        case .maintenanceMode:
            return "Versuche es in ein paar Minuten erneut"
        default:
            return "Versuche es erneut"
        }
    }
}

// MARK: - Result Extensions
extension Result {
    func handleError<T>(logger: LoggerProtocol, fallback: T) -> T? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            logger.error("Operation failed: \(error.localizedDescription)")
            return fallback
        }
    }
    
    func mapError<T>(_ transform: (Error) -> T) -> Result<Success, T> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

// MARK: - Error Recovery
extension Error {
    func recover<T>(with fallback: T) -> T {
        return fallback
    }
    
    func recover<T>(with fallback: () -> T) -> T {
        return fallback()
    }
}

// MARK: - Async Error Handling
func withErrorHandling<T>(
    logger: LoggerProtocol,
    operation: () async throws -> T,
    fallback: T
) async -> T {
    do {
        return try await operation()
    } catch {
        logger.error("Operation failed: \(error.localizedDescription)")
        return fallback
    }
}

func withErrorHandling<T>(
    logger: LoggerProtocol,
    operation: () async throws -> T,
    fallback: () -> T
) async -> T {
    do {
        return try await operation()
    } catch {
        logger.error("Operation failed: \(error.localizedDescription)")
        return fallback()
    }
}