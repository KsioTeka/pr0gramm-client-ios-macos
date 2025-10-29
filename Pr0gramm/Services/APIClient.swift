import Foundation

// MARK: - Generic API Client (SRP: Only handles HTTP communication)
class APIClient: APIClientProtocol {
    
    // MARK: - Dependencies
    private let baseURL: URL
    private let logger: LoggerProtocol
    private let session: URLSession
    
    // MARK: - Initialization
    init(baseURL: URL = URL(string: "https://pr0gramm.com/api")!, logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.baseURL = baseURL
        self.logger = logger
        self.session = URLSession.shared
    }
    
    // MARK: - Public Methods
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        logger.debug("Making \(endpoint.method.rawValue) request to \(endpoint.path)")
        
        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response)
            let result = try JSONDecoder().decode(T.self, from: data)
            logger.debug("Successfully decoded response for \(endpoint.path)")
            return result
        } catch {
            logger.error("Request failed for \(endpoint.path): \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(for: endpoint)
        logger.debug("Making \(endpoint.method.rawValue) request to \(endpoint.path)")
        
        do {
            let (_, response) = try await session.data(for: request)
            try validateResponse(response)
            logger.debug("Successfully completed void request for \(endpoint.path)")
        } catch {
            logger.error("Void request failed for \(endpoint.path): \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    // MARK: - Private Methods
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = endpoint.parameters?.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.authenticationRequired
            } else if httpResponse.statusCode == 429 {
                throw APIError.rateLimited
            } else if httpResponse.statusCode == 503 {
                throw APIError.maintenanceMode
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        }
    }
    
    private func mapError(_ error: Error) -> APIError {
        if let urlError = error as? URLError {
            return .networkFailure
        } else if error is DecodingError {
            return .decodingError
        } else if let apiError = error as? APIError {
            return apiError
        } else {
            return .networkFailure
        }
    }
}

// MARK: - Mock API Client for Testing
#if DEBUG
class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let key = "\(endpoint.method.rawValue):\(endpoint.path)"
        
        if let error = mockErrors[key] {
            throw error
        }
        
        if let response = mockResponses[key] as? T {
            return response
        }
        
        throw APIError.invalidResponse
    }
    
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let key = "\(endpoint.method.rawValue):\(endpoint.path)"
        
        if let error = mockErrors[key] {
            throw error
        }
    }
}
#endif