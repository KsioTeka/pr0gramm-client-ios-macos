import Foundation

// MARK: - API Endpoints for State of the Art Architecture

// MARK: - Login Endpoint
struct LoginEndpoint: APIEndpoint {
    let credentials: LoginRequest
    
    var path: String { "/user/login" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        var params = [
            "name": credentials.username,
            "password": credentials.password
        ]
        
        if let captcha = credentials.captcha, let token = credentials.token {
            params["captcha"] = captcha
            params["token"] = token
        }
        
        return params.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

// MARK: - Logout Endpoint
struct LogoutEndpoint: APIEndpoint {
    var path: String { "/user/logout" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? { nil }
}

// MARK: - Captcha Endpoint
struct CaptchaEndpoint: APIEndpoint {
    var path: String { "/user/captcha" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? { nil }
    var body: Data? { nil }
}

// MARK: - Profile Info Endpoint
struct ProfileInfoEndpoint: APIEndpoint {
    let username: String
    
    var path: String { "/profile/info" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? {
        ["name": username, "flags": "31"]
    }
    var body: Data? { nil }
}

// MARK: - Follow List Endpoint
struct FollowListEndpoint: APIEndpoint {
    var path: String { "/user/followlist" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? { ["flags": "31"] }
    var body: Data? { nil }
}

// MARK: - Follow User Endpoint
struct FollowUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/follow" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

// MARK: - Unfollow User Endpoint
struct UnfollowUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/unfollow" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

// MARK: - Subscribe User Endpoint
struct SubscribeUserEndpoint: APIEndpoint {
    let name: String
    
    var path: String { "/profile/subscribe" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "name=\(name)".data(using: .utf8)
    }
}

// MARK: - Unsubscribe User Endpoint
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

// MARK: - Vote Item Endpoint
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

// MARK: - Vote Comment Endpoint
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

// MARK: - Vote Tag Endpoint
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

// MARK: - Favorite Comment Endpoint
struct FavoriteCommentEndpoint: APIEndpoint {
    let commentId: Int
    
    var path: String { "/comments/fav" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(commentId)".data(using: .utf8)
    }
}

// MARK: - Unfavorite Comment Endpoint
struct UnfavoriteCommentEndpoint: APIEndpoint {
    let commentId: Int
    
    var path: String { "/comments/unfav" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? {
        "id=\(commentId)".data(using: .utf8)
    }
}

// MARK: - Items Endpoint
struct ItemsEndpoint: APIEndpoint {
    let flags: Int
    let promoted: Int?
    let tags: String?
    let user: String?
    let older: Int?
    let newer: Int?
    
    var path: String { "/items/get" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? {
        var params: [String: String] = ["flags": "\(flags)"]
        
        if let promoted = promoted {
            params["promoted"] = "\(promoted)"
        }
        
        if let tags = tags {
            params["tags"] = tags
        }
        
        if let user = user {
            params["user"] = user
        }
        
        if let older = older {
            params["older"] = "\(older)"
        }
        
        if let newer = newer {
            params["newer"] = "\(newer)"
        }
        
        return params
    }
    var body: Data? { nil }
}

// MARK: - Items Info Endpoint
struct ItemsInfoEndpoint: APIEndpoint {
    let itemId: Int
    
    var path: String { "/items/info" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? {
        ["itemId": "\(itemId)"]
    }
    var body: Data? { nil }
}