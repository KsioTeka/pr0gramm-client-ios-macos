import Foundation
import Security

// MARK: - Session Manager (SRP: Only handles session storage)
class SessionManager: SessionManagerProtocol {
    
    // MARK: - Dependencies
    private let keychainService: KeychainServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Constants
    private let sessionCookieKey = "pr0grammSessionCookie_v1"
    private let sessionUsernameKey = "pr0grammUsername_v1"
    private let sessionCookieName = "me"
    
    // MARK: - Initialization
    init(keychainService: KeychainServiceProtocol, logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.keychainService = keychainService
        self.logger = logger
    }
    
    // MARK: - Public Methods
    func saveSession(cookie: HTTPCookie, username: String) async -> Bool {
        logger.info("Saving session for user: \(username)")
        
        let cookieSaved = saveCookie(cookie, forKey: sessionCookieKey)
        let usernameSaved = keychainService.saveString(username, forKey: sessionUsernameKey)
        
        if cookieSaved && usernameSaved {
            logger.info("Session saved successfully")
            return true
        } else {
            logger.error("Failed to save session - Cookie: \(cookieSaved), Username: \(usernameSaved)")
            return false
        }
    }
    
    func loadSession() async -> (cookie: HTTPCookie?, username: String?) {
        logger.info("Loading session from keychain")
        
        guard let username = keychainService.loadString(forKey: sessionUsernameKey) else {
            logger.info("No username found in keychain")
            return (nil, nil)
        }
        
        guard let cookie = loadCookie(forKey: sessionCookieKey) else {
            logger.info("No session cookie found in keychain")
            return (nil, username)
        }
        
        // Check if cookie is expired
        if let expiryDate = cookie.expiresDate, expiryDate < Date() {
            logger.info("Session cookie has expired")
            await clearSession()
            return (nil, username)
        }
        
        logger.info("Session loaded successfully for user: \(username)")
        return (cookie, username)
    }
    
    func clearSession() async {
        logger.info("Clearing session from keychain")
        
        let cookieDeleted = keychainService.delete(forKey: sessionCookieKey)
        let usernameDeleted = keychainService.delete(forKey: sessionUsernameKey)
        
        if cookieDeleted && usernameDeleted {
            logger.info("Session cleared successfully")
        } else {
            logger.warning("Failed to clear session completely - Cookie: \(cookieDeleted), Username: \(usernameDeleted)")
        }
    }
    
    // MARK: - Private Methods
    private func saveCookie(_ cookie: HTTPCookie, forKey key: String) -> Bool {
        guard let properties = cookie.properties else {
            logger.error("Failed to get cookie properties")
            return false
        }
        
        // Convert Date to TimeInterval for JSON serialization
        var serializableProperties = properties
        if let expiresDate = properties[HTTPCookiePropertyKey.expires] as? Date {
            let timestamp = expiresDate.timeIntervalSince1970
            serializableProperties[HTTPCookiePropertyKey("expiresDateTimestamp")] = timestamp
            serializableProperties.removeValue(forKey: HTTPCookiePropertyKey.expires)
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: serializableProperties, options: []) else {
            logger.error("Failed to serialize cookie properties")
            return false
        }
        
        return keychainService.save(data, forKey: key)
    }
    
    private func loadCookie(forKey key: String) -> HTTPCookie? {
        guard let data = keychainService.load(forKey: key) else {
            return nil
        }
        
        guard let properties = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            logger.error("Failed to deserialize cookie properties")
            return nil
        }
        
        // Convert timestamp back to Date
        var cookieProperties: [HTTPCookiePropertyKey: Any] = [:]
        for (stringKey, value) in properties {
            let propertyKey = HTTPCookiePropertyKey(stringKey)
            if stringKey == "expiresDateTimestamp", let timestamp = value as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                cookieProperties[HTTPCookiePropertyKey.expires] = date
            } else {
                cookieProperties[propertyKey] = value
            }
        }
        
        return HTTPCookie(properties: cookieProperties)
    }
}