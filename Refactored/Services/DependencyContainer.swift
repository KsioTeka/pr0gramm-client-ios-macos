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
        let appSettings = AppSettings(
            cacheService: cacheService,
            logger: logger
        )
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

// MARK: - Main Auth Service Protocol
protocol MainAuthServiceProtocol: ObservableObject {
    var isLoggedIn: Bool { get }
    var currentUser: UserInfo? { get }
    var isLoading: Bool { get }
    var loginError: String? { get }
    var needsCaptcha: Bool { get }
    var captchaImage: UIImage? { get }
    var captchaToken: String? { get }
    
    var favoritedItemIDs: Set<Int> { get }
    var votedItemStates: [Int: Int] { get }
    var favoritedCommentIDs: Set<Int> { get }
    var votedCommentStates: [Int: Int] { get }
    var votedTagStates: [Int: Int] { get }
    var followedUsers: [FollowListItem] { get }
    var subscribedUsernames: Set<String> { get }
    
    func login(username: String, password: String, captchaAnswer: String?) async
    func logout() async
    func checkSession() async
    func fetchCaptcha() async
    func followUser(name: String) async
    func unfollowUser(name: String) async
    func subscribeToUser(name: String) async
    func unsubscribeFromUser(name: String, keepFollow: Bool) async
    func voteItem(itemId: Int, voteType: Int) async
    func voteComment(commentId: Int, voteType: Int) async
    func voteTag(tagId: Int, voteType: Int) async
    func favoriteComment(commentId: Int) async
    func unfavoriteComment(commentId: Int) async
}

// MARK: - Main Auth Service (Coordinator)
@MainActor
class MainAuthService: ObservableObject, MainAuthServiceProtocol {
    
    // MARK: - Dependencies
    private let authenticationService: AuthenticationServiceProtocol
    private let sessionManager: SessionManagerProtocol
    private let followManager: FollowManagerProtocol
    private let voteManager: VoteManagerProtocol
    private let settingsService: SettingsServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Published Properties (Delegated)
    var isLoggedIn: Bool { authenticationService.isLoggedIn }
    var currentUser: UserInfo? { authenticationService.currentUser }
    var isLoading: Bool { authenticationService.isLoading }
    var loginError: String? { authenticationService.loginError }
    var needsCaptcha: Bool { authenticationService.needsCaptcha }
    var captchaImage: UIImage? { authenticationService.captchaImage }
    var captchaToken: String? { authenticationService.captchaToken }
    
    var favoritedItemIDs: Set<Int> { voteManager.favoritedItemIDs }
    var votedItemStates: [Int: Int] { voteManager.votedItemStates }
    var favoritedCommentIDs: Set<Int> { voteManager.favoritedCommentIDs }
    var votedCommentStates: [Int: Int] { voteManager.votedCommentStates }
    var votedTagStates: [Int: Int] { voteManager.votedTagStates }
    var followedUsers: [FollowListItem] { followManager.followedUsers }
    var subscribedUsernames: Set<String> { followManager.subscribedUsernames }
    
    // MARK: - Initialization
    init(
        authenticationService: AuthenticationServiceProtocol,
        sessionManager: SessionManagerProtocol,
        followManager: FollowManagerProtocol,
        voteManager: VoteManagerProtocol,
        settingsService: SettingsServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.authenticationService = authenticationService
        self.sessionManager = sessionManager
        self.followManager = followManager
        self.voteManager = voteManager
        self.settingsService = settingsService
        self.logger = logger
        
        setupObservers()
    }
    
    // MARK: - Public Methods (Delegated)
    func login(username: String, password: String, captchaAnswer: String?) async {
        await authenticationService.login(username: username, password: password, captchaAnswer: captchaAnswer)
    }
    
    func logout() async {
        await authenticationService.logout()
    }
    
    func checkSession() async {
        let isValid = await authenticationService.checkSession()
        if isValid {
            await loadFollowList()
        }
    }
    
    func fetchCaptcha() async {
        await authenticationService.fetchCaptcha()
    }
    
    func followUser(name: String) async {
        do {
            try await followManager.followUser(name: name)
        } catch {
            logger.error("Failed to follow user \(name): \(error.localizedDescription)")
        }
    }
    
    func unfollowUser(name: String) async {
        do {
            try await followManager.unfollowUser(name: name)
        } catch {
            logger.error("Failed to unfollow user \(name): \(error.localizedDescription)")
        }
    }
    
    func subscribeToUser(name: String) async {
        do {
            try await followManager.subscribeToUser(name: name)
        } catch {
            logger.error("Failed to subscribe to user \(name): \(error.localizedDescription)")
        }
    }
    
    func unsubscribeFromUser(name: String, keepFollow: Bool) async {
        do {
            try await followManager.unsubscribeFromUser(name: name, keepFollow: keepFollow)
        } catch {
            logger.error("Failed to unsubscribe from user \(name): \(error.localizedDescription)")
        }
    }
    
    func voteItem(itemId: Int, voteType: Int) async {
        do {
            try await voteManager.voteItem(itemId: itemId, voteType: voteType)
        } catch {
            logger.error("Failed to vote item \(itemId): \(error.localizedDescription)")
        }
    }
    
    func voteComment(commentId: Int, voteType: Int) async {
        do {
            try await voteManager.voteComment(commentId: commentId, voteType: voteType)
        } catch {
            logger.error("Failed to vote comment \(commentId): \(error.localizedDescription)")
        }
    }
    
    func voteTag(tagId: Int, voteType: Int) async {
        do {
            try await voteManager.voteTag(tagId: tagId, voteType: voteType)
        } catch {
            logger.error("Failed to vote tag \(tagId): \(error.localizedDescription)")
        }
    }
    
    func favoriteComment(commentId: Int) async {
        do {
            try await voteManager.favoriteComment(commentId: commentId)
        } catch {
            logger.error("Failed to favorite comment \(commentId): \(error.localizedDescription)")
        }
    }
    
    func unfavoriteComment(commentId: Int) async {
        do {
            try await voteManager.unfavoriteComment(commentId: commentId)
        } catch {
            logger.error("Failed to unfavorite comment \(commentId): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Setup any necessary observers between services
    }
    
    private func loadFollowList() async {
        do {
            _ = try await followManager.getFollowList()
        } catch {
            logger.error("Failed to load follow list: \(error.localizedDescription)")
        }
    }
}