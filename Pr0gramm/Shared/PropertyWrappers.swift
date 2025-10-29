import Foundation
import Combine

// MARK: - UserDefaults Property Wrapper
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    private let userDefaults: UserDefaults
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get {
            userDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

// MARK: - UserDefaults with Publisher Support
@propertyWrapper
struct UserDefaultPublished<T> {
    let key: String
    let defaultValue: T
    private let userDefaults: UserDefaults
    private let subject: CurrentValueSubject<T, Never>
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
        self.subject = CurrentValueSubject(userDefaults.object(forKey: key) as? T ?? defaultValue)
    }
    
    var wrappedValue: T {
        get {
            subject.value
        }
        set {
            userDefaults.set(newValue, forKey: key)
            subject.send(newValue)
        }
    }
    
    var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }
}

// MARK: - Codable UserDefaults
@propertyWrapper
struct UserDefaultCodable<T: Codable> {
    let key: String
    let defaultValue: T
    private let userDefaults: UserDefaults
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get {
            guard let data = userDefaults.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: key)
            }
        }
    }
}

// MARK: - Optional UserDefaults
@propertyWrapper
struct UserDefaultOptional<T> {
    let key: String
    private let userDefaults: UserDefaults
    
    init(key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T? {
        get {
            userDefaults.object(forKey: key) as? T
        }
        set {
            if let newValue = newValue {
                userDefaults.set(newValue, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}