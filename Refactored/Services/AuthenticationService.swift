import Foundation
import Combine

// MARK: - Authentication Service (SRP: Only handles authentication)
@MainActor
class AuthenticationService: ObservableObject, AuthenticationServiceProtocol {
    
    // MARK: - Dependencies
    private let apiClient: APIClientProtocol
    private let sessionManager: SessionManagerProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Published Properties
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserInfo?
    @Published var isLoading: Bool = false
    @Published var loginError: String?
    @Published var needsCaptcha: Bool = false
    @Published var captchaImage: UIImage?
    @Published var captchaToken: String?
    
    // MARK: - Initialization
    init(apiClient: APIClientProtocol, sessionManager: SessionManagerProtocol, logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.apiClient = apiClient
        self.sessionManager = sessionManager
        self.logger = logger
    }
    
    // MARK: - Public Methods
    func login(username: String, password: String, captchaAnswer: String? = nil) async {
        guard !isLoading else {
            logger.warning("Login attempt skipped: Already loading")
            return
        }
        
        logger.info("Attempting login for user: \(username)")
        await setLoadingState(true)
        await clearErrors()
        
        do {
            let credentials = LoginRequest(
                username: username,
                password: password,
                captcha: captchaAnswer,
                token: captchaToken
            )
            
            let loginResponse = try await performLogin(credentials: credentials)
            await handleLoginResponse(loginResponse, username: username)
            
        } catch {
            await handleLoginError(error)
        }
        
        await setLoadingState(false)
    }
    
    func logout() async {
        guard isLoggedIn && !isLoading else {
            logger.warning("Logout skipped: Not logged in or already loading")
            return
        }
        
        logger.info("Attempting logout for user: \(currentUser?.name ?? "Unknown")")
        await setLoadingState(true)
        
        do {
            try await apiClient.requestVoid(LogoutEndpoint())
            logger.info("Logout successful via API")
        } catch {
            logger.error("API logout failed: \(error.localizedDescription)")
        }
        
        await performLogoutCleanup()
        await setLoadingState(false)
    }
    
    func checkSession() async -> Bool {
        logger.info("Checking session validity")
        
        let sessionData = await sessionManager.loadSession()
        guard let cookie = sessionData.cookie, let username = sessionData.username else {
            logger.info("No valid session found")
            return false
        }
        
        // Validate session with API
        do {
            let profileResponse = try await apiClient.request(ProfileInfoEndpoint(username: username))
            await MainActor.run {
                self.currentUser = UserInfo(
                    id: profileResponse.user.id,
                    name: profileResponse.user.name,
                    registered: profileResponse.user.registered ?? 0,
                    score: profileResponse.user.score ?? 0,
                    mark: profileResponse.user.mark,
                    badges: profileResponse.badges,
                    collections: profileResponse.collections
                )
                self.isLoggedIn = true
            }
            logger.info("Session is valid for user: \(username)")
            return true
        } catch {
            logger.warning("Session validation failed: \(error.localizedDescription)")
            await sessionManager.clearSession()
            return false
        }
    }
    
    func fetchCaptcha() async {
        logger.info("Fetching captcha")
        
        do {
            let captchaResponse = try await apiClient.request(CaptchaEndpoint())
            await MainActor.run {
                self.captchaToken = captchaResponse.token
                self.captchaImage = self.decodeCaptchaImage(captchaResponse.captcha)
                self.needsCaptcha = true
            }
            logger.info("Captcha fetched successfully")
        } catch {
            logger.error("Failed to fetch captcha: \(error.localizedDescription)")
            await MainActor.run {
                self.loginError = "Captcha konnte nicht geladen werden"
            }
        }
    }
    
    // MARK: - Private Methods
    private func performLogin(credentials: LoginRequest) async throws -> LoginResponse {
        let endpoint = LoginEndpoint(credentials: credentials)
        return try await apiClient.request(endpoint)
    }
    
    private func handleLoginResponse(_ response: LoginResponse, username: String) async {
        if response.success {
            logger.info("Login successful for user: \(username)")
            await loadUserProfile(username: username)
            await MainActor.run {
                self.isLoggedIn = true
                self.needsCaptcha = false
                self.captchaToken = nil
                self.captchaImage = nil
            }
        } else {
            await handleLoginFailure(response, username: username)
        }
    }
    
    private func handleLoginFailure(_ response: LoginResponse, username: String) async {
        if let ban = response.ban, ban.banned {
            let banReason = ban.reason
            let banEnd = ban.till.map { Date(timeIntervalSince1970: TimeInterval($0)).formatted() } ?? "Unbekannt"
            await MainActor.run {
                self.loginError = "Benutzer ist gebannt. Grund: \(banReason) (Bis: \(banEnd))"
            }
            logger.warning("Login failed: User \(username) is banned")
        } else {
            await MainActor.run {
                self.loginError = response.error ?? "Falsche Anmeldedaten"
            }
            logger.warning("Login failed: \(response.error ?? "Unknown error")")
            await fetchCaptcha()
        }
    }
    
    private func loadUserProfile(username: String) async {
        do {
            let profileResponse = try await apiClient.request(ProfileInfoEndpoint(username: username))
            await MainActor.run {
                self.currentUser = UserInfo(
                    id: profileResponse.user.id,
                    name: profileResponse.user.name,
                    registered: profileResponse.user.registered ?? 0,
                    score: profileResponse.user.score ?? 0,
                    mark: profileResponse.user.mark,
                    badges: profileResponse.badges,
                    collections: profileResponse.collections
                )
            }
            logger.info("User profile loaded for: \(username)")
        } catch {
            logger.error("Failed to load user profile: \(error.localizedDescription)")
        }
    }
    
    private func handleLoginError(_ error: Error) async {
        logger.error("Login failed with error: \(error.localizedDescription)")
        await MainActor.run {
            self.loginError = "Fehler beim Login: \(error.localizedDescription)"
        }
    }
    
    private func performLogoutCleanup() async {
        logger.debug("Performing logout cleanup")
        await sessionManager.clearSession()
        await MainActor.run {
            self.isLoggedIn = false
            self.currentUser = nil
            self.needsCaptcha = false
            self.captchaToken = nil
            self.captchaImage = nil
        }
    }
    
    private func setLoadingState(_ loading: Bool) async {
        await MainActor.run {
            self.isLoading = loading
        }
    }
    
    private func clearErrors() async {
        await MainActor.run {
            self.loginError = nil
        }
    }
    
    private func decodeCaptchaImage(_ base64String: String) -> UIImage? {
        var cleanBase64 = base64String
        if let commaRange = base64String.range(of: ",") {
            cleanBase64 = String(base64String[commaRange.upperBound...])
        }
        
        guard let imageData = Data(base64Encoded: cleanBase64) else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
}

// MARK: - Supporting Types
struct LoginRequest {
    let username: String
    let password: String
    let captcha: String?
    let token: String?
}

// MARK: - API Endpoints
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

struct LogoutEndpoint: APIEndpoint {
    var path: String { "/user/logout" }
    var method: HTTPMethod { .POST }
    var parameters: [String: String]? { nil }
    var body: Data? { nil }
}

struct CaptchaEndpoint: APIEndpoint {
    var path: String { "/user/captcha" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? { nil }
    var body: Data? { nil }
}

struct ProfileInfoEndpoint: APIEndpoint {
    let username: String
    
    var path: String { "/profile/info" }
    var method: HTTPMethod { .GET }
    var parameters: [String: String]? {
        ["name": username, "flags": "31"]
    }
    var body: Data? { nil }
}