import Foundation
import Combine

// MARK: - Authentication Protocols
protocol AuthenticationServiceProtocol {
    func login(username: String, password: String, captchaAnswer: String?) async throws -> LoginResponse
    func logout() async throws
    func checkSession() async -> Bool
}

protocol SessionManagerProtocol {
    func saveSession(cookie: HTTPCookie, username: String) async -> Bool
    func loadSession() async -> (cookie: HTTPCookie?, username: String?)
    func clearSession() async
}

// MARK: - Follow Management Protocols
protocol FollowManagerProtocol {
    func followUser(name: String) async throws
    func unfollowUser(name: String) async throws
    func subscribeToUser(name: String) async throws
    func unsubscribeFromUser(name: String, keepFollow: Bool) async throws
    func getFollowList() async throws -> [FollowListItem]
}

// MARK: - Vote Management Protocols
protocol VoteManagerProtocol {
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

enum HTTPMethod: String {
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
protocol SettingsServiceProtocol {
    var isVideoMuted: Bool { get set }
    var feedType: FeedType { get set }
    var showSFW: Bool { get set }
    var showNSFW: Bool { get set }
    var showNSFL: Bool { get set }
    var showPOL: Bool { get set }
    var apiFlags: Int { get }
}

// MARK: - Keychain Protocols
protocol KeychainServiceProtocol {
    func save(_ data: Data, forKey key: String) -> Bool
    func load(forKey key: String) -> Data?
    func delete(forKey key: String) -> Bool
    func saveString(_ string: String, forKey key: String) -> Bool
    func loadString(forKey key: String) -> String?
}