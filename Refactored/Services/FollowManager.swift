import Foundation
import Combine

// MARK: - Follow Manager (SRP: Only handles follow operations)
@MainActor
class FollowManager: ObservableObject, FollowManagerProtocol {
    
    // MARK: - Dependencies
    private let apiClient: APIClientProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Published Properties
    @Published var followedUsers: [FollowListItem] = []
    @Published var subscribedUsernames: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    @Published private(set) var isModifying: [String: Bool] = [:]
    
    // MARK: - Initialization
    init(apiClient: APIClientProtocol, logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.apiClient = apiClient
        self.logger = logger
    }
    
    // MARK: - Public Methods
    func getFollowList() async throws -> [FollowListItem] {
        logger.info("Fetching follow list")
        await setLoadingState(true)
        await clearError()
        
        do {
            let response = try await apiClient.request(FollowListEndpoint())
            await MainActor.run {
                self.followedUsers = response.list.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.subscribedUsernames = Set(self.followedUsers.filter { $0.isSubscribed }.map { $0.name })
            }
            logger.info("Successfully fetched \(response.list.count) followed users")
            await setLoadingState(false)
            return response.list
        } catch {
            await handleError(error)
            await setLoadingState(false)
            throw error
        }
    }
    
    func followUser(name: String) async throws {
        logger.info("Following user: \(name)")
        await setModifyingState(true, for: name)
        
        // Optimistic update
        let wasFollowing = followedUsers.contains { $0.name == name }
        if !wasFollowing {
            let newItem = FollowListItem(
                subscribed: 0,
                name: name,
                mark: 0,
                followCreated: Int(Date().timeIntervalSince1970),
                itemId: nil,
                thumb: nil,
                preview: nil,
                lastPost: nil
            )
            await MainActor.run {
                self.followedUsers.append(newItem)
                self.followedUsers.sort { $0.name.lowercased() < $1.name.lowercased() }
            }
        }
        
        do {
            let response = try await apiClient.request(FollowUserEndpoint(name: name))
            if response.follows == true {
                logger.info("Successfully followed user: \(name)")
            } else {
                logger.warning("Follow action did not result in follows=true")
                if !wasFollowing {
                    await MainActor.run {
                        self.followedUsers.removeAll { $0.name == name }
                    }
                }
            }
        } catch {
            logger.error("Failed to follow user \(name): \(error.localizedDescription)")
            if !wasFollowing {
                await MainActor.run {
                    self.followedUsers.removeAll { $0.name == name }
                }
            }
            throw error
        }
        
        await setModifyingState(false, for: name)
    }
    
    func unfollowUser(name: String) async throws {
        logger.info("Unfollowing user: \(name)")
        await setModifyingState(true, for: name)
        
        let originalItem = followedUsers.first { $0.name == name }
        await MainActor.run {
            self.followedUsers.removeAll { $0.name == name }
            self.subscribedUsernames.remove(name)
        }
        
        do {
            let response = try await apiClient.request(UnfollowUserEndpoint(name: name))
            if response.follows == false {
                logger.info("Successfully unfollowed user: \(name)")
            } else {
                logger.warning("Unfollow action did not result in follows=false")
                if let item = originalItem {
                    await MainActor.run {
                        self.followedUsers.append(item)
                        self.followedUsers.sort { $0.name.lowercased() < $1.name.lowercased() }
                        if item.isSubscribed {
                            self.subscribedUsernames.insert(name)
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to unfollow user \(name): \(error.localizedDescription)")
            if let item = originalItem {
                await MainActor.run {
                    self.followedUsers.append(item)
                    self.followedUsers.sort { $0.name.lowercased() < $1.name.lowercased() }
                    if item.isSubscribed {
                        self.subscribedUsernames.insert(name)
                    }
                }
            }
            throw error
        }
        
        await setModifyingState(false, for: name)
    }
    
    func subscribeToUser(name: String) async throws {
        logger.info("Subscribing to user: \(name)")
        await setModifyingState(true, for: name)
        
        let wasSubscribed = subscribedUsernames.contains(name)
        await MainActor.run {
            self.subscribedUsernames.insert(name)
        }
        
        if let index = followedUsers.firstIndex(where: { $0.name == name }) {
            let oldItem = followedUsers[index]
            let newItem = FollowListItem(
                subscribed: 1,
                name: oldItem.name,
                mark: oldItem.mark,
                followCreated: oldItem.followCreated,
                itemId: oldItem.itemId,
                thumb: oldItem.thumb,
                preview: oldItem.preview,
                lastPost: oldItem.lastPost
            )
            await MainActor.run {
                self.followedUsers[index] = newItem
            }
        }
        
        do {
            let response = try await apiClient.request(SubscribeUserEndpoint(name: name))
            if response.subscribed == true {
                logger.info("Successfully subscribed to user: \(name)")
            } else {
                logger.warning("Subscribe action did not result in subscribed=true")
                if !wasSubscribed {
                    await MainActor.run {
                        self.subscribedUsernames.remove(name)
                    }
                    if let index = followedUsers.firstIndex(where: { $0.name == name }) {
                        let oldItem = followedUsers[index]
                        let newItem = FollowListItem(
                            subscribed: 0,
                            name: oldItem.name,
                            mark: oldItem.mark,
                            followCreated: oldItem.followCreated,
                            itemId: oldItem.itemId,
                            thumb: oldItem.thumb,
                            preview: oldItem.preview,
                            lastPost: oldItem.lastPost
                        )
                        await MainActor.run {
                            self.followedUsers[index] = newItem
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to subscribe to user \(name): \(error.localizedDescription)")
            if !wasSubscribed {
                await MainActor.run {
                    self.subscribedUsernames.remove(name)
                }
            }
            throw error
        }
        
        await setModifyingState(false, for: name)
    }
    
    func unsubscribeFromUser(name: String, keepFollow: Bool) async throws {
        logger.info("Unsubscribing from user: \(name), keepFollow: \(keepFollow)")
        await setModifyingState(true, for: name)
        
        let wasSubscribed = subscribedUsernames.contains(name)
        let originalItem = followedUsers.first { $0.name == name }
        
        await MainActor.run {
            self.subscribedUsernames.remove(name)
        }
        
        if let index = followedUsers.firstIndex(where: { $0.name == name }) {
            if !keepFollow {
                await MainActor.run {
                    self.followedUsers.remove(at: index)
                }
            } else {
                let oldItem = followedUsers[index]
                let newItem = FollowListItem(
                    subscribed: 0,
                    name: oldItem.name,
                    mark: oldItem.mark,
                    followCreated: oldItem.followCreated,
                    itemId: oldItem.itemId,
                    thumb: oldItem.thumb,
                    preview: oldItem.preview,
                    lastPost: oldItem.lastPost
                )
                await MainActor.run {
                    self.followedUsers[index] = newItem
                }
            }
        }
        
        do {
            let response = try await apiClient.request(UnsubscribeUserEndpoint(name: name, keepFollow: keepFollow))
            if response.subscribed == false {
                logger.info("Successfully unsubscribed from user: \(name)")
            } else {
                logger.warning("Unsubscribe action did not result in subscribed=false")
                if wasSubscribed {
                    await MainActor.run {
                        self.subscribedUsernames.insert(name)
                    }
                }
            }
        } catch {
            logger.error("Failed to unsubscribe from user \(name): \(error.localizedDescription)")
            if wasSubscribed {
                await MainActor.run {
                    self.subscribedUsernames.insert(name)
                }
            }
            throw error
        }
        
        await setModifyingState(false, for: name)
    }
    
    // MARK: - Private Methods
    private func setLoadingState(_ loading: Bool) async {
        await MainActor.run {
            self.isLoading = loading
        }
    }
    
    private func setModifyingState(_ modifying: Bool, for user: String) async {
        await MainActor.run {
            if modifying {
                self.isModifying[user] = true
            } else {
                self.isModifying[user] = nil
            }
        }
    }
    
    private func clearError() async {
        await MainActor.run {
            self.error = nil
        }
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - API Endpoints
struct FollowListEndpoint: APIEndpoint {
    var path: String { "/user/followlist" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? { ["flags": "31"] }
    var body: Data? { nil }
}

struct FollowUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/follow" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

struct UnfollowUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/unfollow" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

struct SubscribeUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/subscribe" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

struct UnsubscribeUserEndpoint: APIEndpoint {
    let name: String
    let keepFollow: Bool
    
    var path: String { "/profile/unsubscribe" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)&keepFollow=\(keepFollow)".data(using: .utf8)
    }
}