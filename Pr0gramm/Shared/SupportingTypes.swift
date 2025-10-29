import Foundation
import UIKit

// MARK: - Supporting Types for State of the Art Architecture

// MARK: - User Info
struct UserInfo: Codable, Hashable {
    let id: Int
    let name: String
    let registered: Int
    let score: Int
    let mark: Int
    let badges: [ApiBadge]?
    let collections: [ApiCollection]?
}

// MARK: - API Badge
struct ApiBadge: Codable, Identifiable, Hashable {
    var id: String { image }
    let image: String
    let description: String?
    let created: Int?
    let link: String?
    let category: String?
}

// MARK: - API Collection
struct ApiCollection: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let keyword: String?
    let isPublic: Int
    let isDefault: Int
    let itemCount: Int
}

// MARK: - Follow List Item
struct FollowListItem: Codable, Identifiable, Hashable {
    var id: String { name }
    let subscribed: Int
    let name: String
    let mark: Int
    let followCreated: Int
    let itemId: Int?
    let thumb: String?
    let preview: String?
    let lastPost: Int?
    
    var isSubscribed: Bool { subscribed == 1 }
}

// MARK: - Login Response
struct LoginResponse: Codable {
    let success: Bool
    let error: String?
    let ban: BanInfo?
    let nonce: NonceInfo?
}

// MARK: - Ban Info
struct BanInfo: Codable {
    let banned: Bool
    let reason: String
    let till: Int?
    let userId: Int?
}

// MARK: - Nonce Info
struct NonceInfo: Codable {
    let nonce: String
}

// MARK: - Captcha Response
struct CaptchaResponse: Codable {
    let captcha: String
    let token: String
}

// MARK: - Profile Info Response
struct ProfileInfoResponse: Codable {
    let user: ProfileUser
    let badges: [ApiBadge]?
    let collections: [ApiCollection]?
}

struct ProfileUser: Codable {
    let id: Int
    let name: String
    let registered: Int?
    let score: Int?
    let mark: Int
}

// MARK: - Follow List Response
struct FollowListResponse: Codable {
    let list: [FollowListItem]
}

// MARK: - Follow Response
struct FollowResponse: Codable {
    let follows: Bool
}

// MARK: - Subscribe Response
struct SubscribeResponse: Codable {
    let subscribed: Bool
}

// MARK: - Vote Response
struct VoteResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Item (for Feed)
struct Item: Identifiable, Codable {
    let id: Int
    let user: String
    let title: String
    let up: Int
    let down: Int
    let created: Int
    let image: String?
    let thumb: String?
}

// MARK: - Item Tag
struct ItemTag: Codable, Identifiable, Hashable {
    let id: Int
    let confidence: Double
    let tag: String
}

// MARK: - Item Comment
struct ItemComment: Codable, Identifiable, Hashable {
    let id: Int
    let parent: Int?
    let content: String
    let created: Int
    var up: Int
    var down: Int
    let confidence: Double?
    let name: String?
    let mark: Int?
    let itemId: Int?
    let thumb: String?

    init(id: Int, parent: Int?, content: String, created: Int, up: Int, down: Int, confidence: Double?, name: String?, mark: Int?, itemId: Int? = nil, thumb: String? = nil) {
        self.id = id
        self.parent = parent
        self.content = content
        self.created = created
        self.up = up
        self.down = down
        self.confidence = confidence
        self.name = name
        self.mark = mark
        self.itemId = itemId
        self.thumb = thumb
    }

    var itemThumbnailUrl: URL? {
        guard let thumb = thumb, !thumb.isEmpty else { return nil }
        return URL(string: "https://img.pr0gramm.com/\(thumb)")
    }
}

// MARK: - Items Info Response
struct ItemsInfoResponse: Codable {
    let tags: [ItemTag]
    let comments: [ItemComment]
}