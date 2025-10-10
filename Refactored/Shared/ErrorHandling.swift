import Foundation

// MARK: - Simplified Error Handling
enum APIError: Error, LocalizedError {
    case networkFailure
    case invalidResponse
    case serverError(Int)
    case authenticationRequired
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "Netzwerkfehler"
        case .invalidResponse:
            return "Ungültige Serverantwort"
        case .serverError(let code):
            return "Serverfehler: \(code)"
        case .authenticationRequired:
            return "Authentifizierung erforderlich"
        case .decodingError:
            return "Datenverarbeitungsfehler"
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