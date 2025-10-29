import Foundation
import Combine

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