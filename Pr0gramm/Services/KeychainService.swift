import Foundation
import Security

// MARK: - Keychain Service (SRP: Only handles keychain operations)
class KeychainService: KeychainServiceProtocol {
    
    // MARK: - Dependencies
    private let logger: LoggerProtocol
    private let serviceName: String
    
    // MARK: - Initialization
    init(logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.logger = logger
        
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            fatalError("Could not retrieve bundle identifier for Keychain service")
        }
        self.serviceName = bundleIdentifier
        
        logger.debug("KeychainService initialized with service name: \(serviceName)")
    }
    
    // MARK: - Public Methods
    func save(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Delete existing item first
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.warning("Failed to delete existing keychain item for key '\(key)' (Error: \(deleteStatus))")
        }
        
        // Add new item
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        if addStatus == errSecSuccess {
            logger.info("Successfully saved data to keychain for key: \(key)")
            return true
        } else {
            logger.error("Failed to save data to keychain for key '\(key)' (Error: \(addStatus))")
            return false
        }
    }
    
    func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            guard let retrievedData = dataTypeRef as? Data else {
                logger.error("Failed to cast retrieved data for key: \(key)")
                return nil
            }
            logger.info("Successfully loaded data from keychain for key: \(key)")
            return retrievedData
        } else if status == errSecItemNotFound {
            logger.info("No data found in keychain for key: \(key)")
            return nil
        } else {
            logger.error("Failed to load data from keychain for key '\(key)' (Error: \(status))")
            return nil
        }
    }
    
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            logger.info("Successfully deleted data from keychain for key: \(key)")
            return true
        } else if status == errSecItemNotFound {
            logger.info("Attempted to delete data for key '\(key)', but item was not found")
            return true
        } else {
            logger.error("Failed to delete data from keychain for key '\(key)' (Error: \(status))")
            return false
        }
    }
    
    func saveString(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else {
            logger.error("Failed to encode string to data for key: \(key)")
            return false
        }
        return save(data, forKey: key)
    }
    
    func loadString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode string data from keychain for key: \(key)")
            return nil
        }
        logger.info("Successfully loaded string from keychain for key: \(key)")
        return string
    }
}