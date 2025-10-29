import Foundation

// MARK: - Dependency Container (IoC Container)
class DependencyContainer {
    
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Services
    private var services: [String: Any] = [:]
    
    private init() {
        setupServices()
    }
    
    // MARK: - Public Methods
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let service = services[key] as? T else {
            fatalError("Service of type \(type) not registered")
        }
        return service
    }
    
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    // MARK: - Private Methods
    private func setupServices() {
        // Logger
        let logger = LoggerFactory.create(for: Self.self)
        register(logger, for: LoggerProtocol.self)
        
        // Keychain Service
        let keychainService = KeychainService(logger: logger)
        register(keychainService, for: KeychainServiceProtocol.self)
        
        // Cache Service
        let cacheService = CacheService(logger: logger)
        register(cacheService, for: CacheServiceProtocol.self)
        
        // API Client
        let apiClient = APIClient(logger: logger)
        register(apiClient, for: APIClientProtocol.self)
        
        // Session Manager
        let sessionManager = SessionManager(
            keychainService: keychainService,
            logger: logger
        )
        register(sessionManager, for: SessionManagerProtocol.self)
        
        // Authentication Service
        let authService = AuthenticationService(
            apiClient: apiClient,
            sessionManager: sessionManager,
            logger: logger
        )
        register(authService, for: AuthenticationServiceProtocol.self)
        
        // Follow Manager
        let followManager = FollowManager(
            apiClient: apiClient,
            logger: logger
        )
        register(followManager, for: FollowManagerProtocol.self)
        
        // Vote Manager
        let voteManager = VoteManager(
            apiClient: apiClient,
            cacheService: cacheService,
            logger: logger
        )
        register(voteManager, for: VoteManagerProtocol.self)
        
        // App Settings
        let appSettings = AppSettings(cacheService: cacheService)
        register(appSettings, for: SettingsServiceProtocol.self)
        
        // Main Auth Service (Coordinator)
        let mainAuthService = MainAuthService(
            authenticationService: authService,
            sessionManager: sessionManager,
            followManager: followManager,
            voteManager: voteManager,
            settingsService: appSettings,
            logger: logger
        )
        register(mainAuthService, for: MainAuthServiceProtocol.self)
    }
}

// MARK: - Property Wrapper for Dependency Injection
@propertyWrapper
struct Injected<T> {
    private let type: T.Type
    
    init(_ type: T.Type) {
        self.type = type
    }
    
    var wrappedValue: T {
        DependencyContainer.shared.resolve(type)
    }
}