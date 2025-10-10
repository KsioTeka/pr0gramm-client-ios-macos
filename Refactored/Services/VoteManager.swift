import Foundation
import Combine

// MARK: - Vote Manager (SRP: Only handles voting operations)
@MainActor
class VoteManager: ObservableObject, VoteManagerProtocol {
    
    // MARK: - Dependencies
    private let apiClient: APIClientProtocol
    private let cacheService: CacheServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Published Properties
    @Published var favoritedItemIDs: Set<Int> = []
    @Published var votedItemStates: [Int: Int] = [:]
    @Published var favoritedCommentIDs: Set<Int> = []
    @Published var votedCommentStates: [Int: Int] = [:]
    @Published var votedTagStates: [Int: Int] = [:]
    @Published private(set) var isVoting: [Int: Bool] = [:]
    @Published private(set) var isFavoritingComment: [Int: Bool] = [:]
    @Published private(set) var isVotingComment: [Int: Bool] = [:]
    @Published private(set) var isVotingTag: [Int: Bool] = [:]
    
    // MARK: - Cache Keys
    private let userVotesKey = "pr0grammUserVotes_v1"
    private let favoritedCommentsKey = "pr0grammFavoritedComments_v1"
    private let userCommentVotesKey = "pr0grammUserCommentVotes_v1"
    private let userTagVotesKey = "pr0grammUserTagVotes_v1"
    
    // MARK: - Initialization
    init(apiClient: APIClientProtocol, cacheService: CacheServiceProtocol, logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.apiClient = apiClient
        self.cacheService = cacheService
        self.logger = logger
        loadCachedStates()
    }
    
    // MARK: - Public Methods
    func voteItem(itemId: Int, voteType: Int) async throws {
        guard !(isVoting[itemId] ?? false) else {
            logger.debug("Already voting item \(itemId)")
            return
        }
        
        logger.info("Voting item \(itemId) with vote \(voteType)")
        await setVotingState(true, for: itemId)
        
        let currentVote = votedItemStates[itemId] ?? 0
        let targetVote = calculateTargetVote(currentVote: currentVote, voteType: voteType)
        let previousVoteState = votedItemStates[itemId]
        
        // Optimistic update
        votedItemStates[itemId] = targetVote
        
        do {
            try await apiClient.requestVoid(VoteItemEndpoint(itemId: itemId, vote: targetVote))
            logger.info("Successfully voted \(targetVote) for item \(itemId)")
            await saveVotedStates()
        } catch {
            logger.error("Failed to vote item \(itemId): \(error.localizedDescription)")
            votedItemStates[itemId] = previousVoteState
            await saveVotedStates()
            throw error
        }
        
        await setVotingState(false, for: itemId)
    }
    
    func voteComment(commentId: Int, voteType: Int) async throws {
        guard !(isVotingComment[commentId] ?? false) else {
            logger.debug("Already voting comment \(commentId)")
            return
        }
        
        logger.info("Voting comment \(commentId) with vote \(voteType)")
        await setCommentVotingState(true, for: commentId)
        
        let currentVote = votedCommentStates[commentId] ?? 0
        let targetVote = calculateTargetVote(currentVote: currentVote, voteType: voteType)
        let previousVoteState = votedCommentStates[commentId]
        
        // Optimistic update
        votedCommentStates[commentId] = targetVote
        
        do {
            try await apiClient.requestVoid(VoteCommentEndpoint(commentId: commentId, vote: targetVote))
            logger.info("Successfully voted \(targetVote) for comment \(commentId)")
            await saveVotedCommentStates()
        } catch {
            logger.error("Failed to vote comment \(commentId): \(error.localizedDescription)")
            votedCommentStates[commentId] = previousVoteState
            await saveVotedCommentStates()
            throw error
        }
        
        await setCommentVotingState(false, for: commentId)
    }
    
    func voteTag(tagId: Int, voteType: Int) async throws {
        guard !(isVotingTag[tagId] ?? false) else {
            logger.debug("Already voting tag \(tagId)")
            return
        }
        
        logger.info("Voting tag \(tagId) with vote \(voteType)")
        await setTagVotingState(true, for: tagId)
        
        let currentVote = votedTagStates[tagId] ?? 0
        let targetVote = calculateTargetVote(currentVote: currentVote, voteType: voteType)
        let previousVoteState = votedTagStates[tagId]
        
        // Optimistic update
        votedTagStates[tagId] = targetVote
        
        do {
            try await apiClient.requestVoid(VoteTagEndpoint(tagId: tagId, vote: targetVote))
            logger.info("Successfully voted \(targetVote) for tag \(tagId)")
            await saveVotedTagStates()
        } catch {
            logger.error("Failed to vote tag \(tagId): \(error.localizedDescription)")
            votedTagStates[tagId] = previousVoteState
            await saveVotedTagStates()
            throw error
        }
        
        await setTagVotingState(false, for: tagId)
    }
    
    func favoriteComment(commentId: Int) async throws {
        guard !(isFavoritingComment[commentId] ?? false) else {
            logger.debug("Already favoriting comment \(commentId)")
            return
        }
        
        logger.info("Favoriting comment \(commentId)")
        await setFavoritingState(true, for: commentId)
        
        let isCurrentlyFavorited = favoritedCommentIDs.contains(commentId)
        let targetState = !isCurrentlyFavorited
        
        // Optimistic update
        if targetState {
            favoritedCommentIDs.insert(commentId)
        } else {
            favoritedCommentIDs.remove(commentId)
        }
        await saveFavoritedCommentIDs()
        
        do {
            if targetState {
                try await apiClient.requestVoid(FavoriteCommentEndpoint(commentId: commentId))
                logger.info("Successfully favorited comment \(commentId)")
            } else {
                try await apiClient.requestVoid(UnfavoriteCommentEndpoint(commentId: commentId))
                logger.info("Successfully unfavorited comment \(commentId)")
            }
        } catch {
            logger.error("Failed to favorite comment \(commentId): \(error.localizedDescription)")
            if targetState {
                favoritedCommentIDs.remove(commentId)
            } else {
                favoritedCommentIDs.insert(commentId)
            }
            await saveFavoritedCommentIDs()
            throw error
        }
        
        await setFavoritingState(false, for: commentId)
    }
    
    func unfavoriteComment(commentId: Int) async throws {
        try await favoriteComment(commentId: commentId)
    }
    
    // MARK: - Private Methods
    private func calculateTargetVote(currentVote: Int, voteType: Int) -> Int {
        if voteType == 1 {
            return (currentVote == 1) ? 0 : 1
        } else if voteType == -1 {
            return (currentVote == -1) ? 0 : -1
        } else {
            logger.error("Invalid voteType \(voteType)")
            return currentVote
        }
    }
    
    private func setVotingState(_ voting: Bool, for itemId: Int) async {
        await MainActor.run {
            if voting {
                self.isVoting[itemId] = true
            } else {
                self.isVoting[itemId] = nil
            }
        }
    }
    
    private func setCommentVotingState(_ voting: Bool, for commentId: Int) async {
        await MainActor.run {
            if voting {
                self.isVotingComment[commentId] = true
            } else {
                self.isVotingComment[commentId] = nil
            }
        }
    }
    
    private func setTagVotingState(_ voting: Bool, for tagId: Int) async {
        await MainActor.run {
            if voting {
                self.isVotingTag[tagId] = true
            } else {
                self.isVotingTag[tagId] = nil
            }
        }
    }
    
    private func setFavoritingState(_ favoriting: Bool, for commentId: Int) async {
        await MainActor.run {
            if favoriting {
                self.isFavoritingComment[commentId] = true
            } else {
                self.isFavoritingComment[commentId] = nil
            }
        }
    }
    
    private func loadCachedStates() {
        loadVotedStates()
        loadFavoritedCommentIDs()
        loadVotedCommentStates()
        loadVotedTagStates()
    }
    
    private func loadVotedStates() {
        Task {
            if let cachedStates: [String: Int] = await cacheService.load(forKey: userVotesKey) {
                let loadedStates = Dictionary(uniqueKeysWithValues: cachedStates.compactMap { (key: String, value: Int) -> (Int, Int)? in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, value)
                })
                await MainActor.run {
                    self.votedItemStates = loadedStates
                }
                logger.debug("Loaded \(loadedStates.count) vote states from cache")
            }
        }
    }
    
    private func loadFavoritedCommentIDs() {
        Task {
            if let cachedIDs: [Int] = await cacheService.load(forKey: favoritedCommentsKey) {
                await MainActor.run {
                    self.favoritedCommentIDs = Set(cachedIDs)
                }
                logger.debug("Loaded \(cachedIDs.count) favorited comment IDs from cache")
            }
        }
    }
    
    private func loadVotedCommentStates() {
        Task {
            if let cachedStates: [String: Int] = await cacheService.load(forKey: userCommentVotesKey) {
                let loadedStates = Dictionary(uniqueKeysWithValues: cachedStates.compactMap { (key: String, value: Int) -> (Int, Int)? in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, value)
                })
                await MainActor.run {
                    self.votedCommentStates = loadedStates
                }
                logger.debug("Loaded \(loadedStates.count) comment vote states from cache")
            }
        }
    }
    
    private func loadVotedTagStates() {
        Task {
            if let cachedStates: [String: Int] = await cacheService.load(forKey: userTagVotesKey) {
                let loadedStates = Dictionary(uniqueKeysWithValues: cachedStates.compactMap { (key: String, value: Int) -> (Int, Int)? in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, value)
                })
                await MainActor.run {
                    self.votedTagStates = loadedStates
                }
                logger.debug("Loaded \(loadedStates.count) tag vote states from cache")
            }
        }
    }
    
    private func saveVotedStates() async {
        let stringKeyedVotes = Dictionary(uniqueKeysWithValues: votedItemStates.map { (String($0.key), $0.value) })
        await cacheService.save(stringKeyedVotes, forKey: userVotesKey)
    }
    
    private func saveFavoritedCommentIDs() async {
        let idsToSave = Array(favoritedCommentIDs)
        await cacheService.save(idsToSave, forKey: favoritedCommentsKey)
    }
    
    private func saveVotedCommentStates() async {
        let stringKeyedVotes = Dictionary(uniqueKeysWithValues: votedCommentStates.map { (String($0.key), $0.value) })
        await cacheService.save(stringKeyedVotes, forKey: userCommentVotesKey)
    }
    
    private func saveVotedTagStates() async {
        let stringKeyedVotes = Dictionary(uniqueKeysWithValues: votedTagStates.map { (String($0.key), $0.value) })
        await cacheService.save(stringKeyedVotes, forKey: userTagVotesKey)
    }
}

// MARK: - API Endpoints
struct VoteItemEndpoint: APIEndpoint {
    let itemId: Int
    let vote: Int
    
    var path: String { "/items/vote" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(itemId)&vote=\(vote)".data(using: .utf8)
    }
}

struct VoteCommentEndpoint: APIEndpoint {
    let commentId: Int
    let vote: Int
    
    var path: String { "/comments/vote" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(commentId)&vote=\(vote)".data(using: .utf8)
    }
}

struct VoteTagEndpoint: APIEndpoint {
    let tagId: Int
    let vote: Int
    
    var path: String { "/tags/vote" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(tagId)&vote=\(vote)".data(using: .utf8)
    }
}

struct FavoriteCommentEndpoint: APIEndpoint {
    let commentId: Int
    
    var path: String { "/comments/fav" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(commentId)".data(using: .utf8)
    }
}

struct UnfavoriteCommentEndpoint: APIEndpoint {
    let commentId: Int
    
    var path: String { "/comments/unfav" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(commentId)".data(using: .utf8)
    }
}