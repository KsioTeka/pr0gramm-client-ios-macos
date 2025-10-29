import Foundation
import Combine

// MARK: - Core Protocols (State of the Art Architecture)

// MARK: - Authentication Protocols
protocol AuthenticationServiceProtocol: ObservableObject {
    var isLoggedIn: Bool { get }
    var currentUser: UserInfo? { get }
    var isLoading: Bool { get }
    var loginError: String? { get }
    var needsCaptcha: Bool { get }
    var captchaImage: UIImage? { get }
    var captchaToken: String? { get }
    
    func login(username: String, password: String, captchaAnswer: String?) async
    func logout() async
    func checkSession() async -> Bool
    func fetchCaptcha() async
}

// MARK: - Session Management Protocols
protocol SessionManagerProtocol {
    func saveSession(cookie: HTTPCookie, username: String) async -> Bool
    func loadSession() async -> (cookie: HTTPCookie?, username: String?)
    func clearSession() async
}

// MARK: - Follow Management Protocols
protocol FollowManagerProtocol: ObservableObject {
    var followedUsers: [FollowListItem] { get }
    var subscribedUsernames: Set<String> { get }
    var isLoading: Bool { get }
    var error: String? { get }
    
    func getFollowList() async throws -> [FollowListItem]
    func followUser(name: String) async throws
    func unfollowUser(name: String) async throws
    func subscribeToUser(name: String) async throws
    func unsubscribeFromUser(name: String, keepFollow: Bool) async throws
}

// MARK: - Vote Management Protocols
protocol VoteManagerProtocol: ObservableObject {
    var favoritedItemIDs: Set<Int> { get }
    var votedItemStates: [Int: Int] { get }
    var favoritedCommentIDs: Set<Int> { get }
    var votedCommentStates: [Int: Int] { get }
    var votedTagStates: [Int: Int] { get }
    
    func voteItem(itemId: Int, voteType: Int) async throws
    func voteComment(commentId: Int, voteType: Int) async throws
    func voteTag(tagId: Int, voteType: Int) async throws
    func favoriteComment(commentId: Int) async throws
    func unfavoriteComment(commentId: Int) async throws
}

// MARK: - API Protocols
protocol APIClientProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T
    func requestVoid(_ endpoint: APIEndpoint) async throws
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: String]? { get }
    var body: Data? { get }
}

enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Cache Protocols
protocol CacheServiceProtocol {
    func save<T: Codable>(_ data: T, forKey key: String) async
    func load<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    func clear(forKey key: String) async
    func clearAll() async
}

// MARK: - Settings Protocols
protocol SettingsServiceProtocol: ObservableObject {
    var isVideoMuted: Bool { get set }
    var feedType: FeedType { get set }
    var showSFW: Bool { get set }
    var showNSFW: Bool { get set }
    var showNSFL: Bool { get set }
    var showPOL: Bool { get set }
    var apiFlags: Int { get }
    
    func updateUserLoginStatusForApiFlags(isLoggedIn: Bool)
    func markItemAsSeen(id: Int)
    func markItemsAsSeen(ids: Set<Int>)
}

// MARK: - Keychain Protocols
protocol KeychainServiceProtocol {
    func save(_ data: Data, forKey key: String) -> Bool
    func load(forKey key: String) -> Data?
    func delete(forKey key: String) -> Bool
    func saveString(_ string: String, forKey key: String) -> Bool
    func loadString(forKey key: String) -> String?
}

// MARK: - Main Coordinator Protocol
protocol MainAuthServiceProtocol: ObservableObject {
    // Authentication
    var isLoggedIn: Bool { get }
    var currentUser: UserInfo? { get }
    var isLoading: Bool { get }
    var loginError: String? { get }
    var needsCaptcha: Bool { get }
    var captchaImage: UIImage? { get }
    var captchaToken: String? { get }
    
    // Follow Management
    var followedUsers: [FollowListItem] { get }
    var subscribedUsernames: Set<String> { get }
    
    // Vote Management
    var favoritedItemIDs: Set<Int> { get }
    var votedItemStates: [Int: Int] { get }
    var favoritedCommentIDs: Set<Int> { get }
    var votedCommentStates: [Int: Int] { get }
    var votedTagStates: [Int: Int] { get }
    
    // Methods
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