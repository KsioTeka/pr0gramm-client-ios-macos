import SwiftUI

// MARK: - Main App
@main
struct Pr0grammApp: App {
    
    // MARK: - Dependencies
    @Injected(LoggerProtocol.self) private var logger
    @Injected(MainAuthServiceProtocol.self) private var authService
    @Injected(SettingsServiceProtocol.self) private var settings
    
    // MARK: - App State
    @State private var isInitialized = false
    
    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(settings)
            } else {
                LoadingView()
            }
        }
    }
    
    init() {
        Task {
            await initializeApp()
        }
    }
    
    // MARK: - Private Methods
    private func initializeApp() async {
        logger.info("Initializing Pr0gramm App")
        
        // Check for existing session
        await authService.checkSession()
        
        await MainActor.run {
            isInitialized = true
        }
        
        logger.info("Pr0gramm App initialized successfully")
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    @EnvironmentObject private var settings: SettingsServiceProtocol
    
    var body: some View {
        Group {
            if authService.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Lade Pr0gramm...")
                .font(.headline)
                .padding(.top)
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    @State private var username = ""
    @State private var password = ""
    @State private var captchaAnswer = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Pr0gramm")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField("Benutzername", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Passwort", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if authService.needsCaptcha {
                        VStack {
                            if let captchaImage = authService.captchaImage {
                                Image(uiImage: captchaImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 100)
                                    .border(Color.gray, width: 1)
                            }
                            
                            TextField("Captcha", text: $captchaAnswer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding(.horizontal)
                
                if let error = authService.loginError {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: login) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Anmelden")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authService.isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Anmeldung")
        }
        .onAppear {
            if authService.needsCaptcha {
                Task {
                    await authService.fetchCaptcha()
                }
            }
        }
    }
    
    private func login() {
        Task {
            await authService.login(
                username: username,
                password: password,
                captchaAnswer: authService.needsCaptcha ? captchaAnswer : nil
            )
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Feed")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Suche")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profil")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Einstellungen")
                }
        }
    }
}

// MARK: - Feed View
struct FeedView: View {
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    @State private var items: [Item] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List(items) { item in
                FeedItemRow(item: item)
            }
            .navigationTitle("Pr0gramm")
            .refreshable {
                await loadItems()
            }
            .onAppear {
                if items.isEmpty {
                    Task {
                        await loadItems()
                    }
                }
            }
        }
    }
    
    private func loadItems() async {
        isLoading = true
        // Implementation for loading feed items
        isLoading = false
    }
}

// MARK: - Feed Item Row
struct FeedItemRow: View {
    let item: Item
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.user)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(item.title)
                .font(.headline)
            
            HStack {
                Button(action: { voteItem(1) }) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(authService.votedItemStates[item.id] == 1 ? .orange : .gray)
                }
                
                Text("\(item.up - item.down)")
                    .font(.caption)
                
                Button(action: { voteItem(-1) }) {
                    Image(systemName: "arrow.down")
                        .foregroundColor(authService.votedItemStates[item.id] == -1 ? .orange : .gray)
                }
                
                Spacer()
                
                Button(action: { favoriteItem() }) {
                    Image(systemName: authService.favoritedItemIDs.contains(item.id) ? "heart.fill" : "heart")
                        .foregroundColor(authService.favoritedItemIDs.contains(item.id) ? .red : .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func voteItem(_ voteType: Int) {
        Task {
            await authService.voteItem(itemId: item.id, voteType: voteType)
        }
    }
    
    private func favoriteItem() {
        // Implementation for favoriting items
    }
}

// MARK: - Search View
struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Item] = []
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                
                List(searchResults) { item in
                    FeedItemRow(item: item)
                }
            }
            .navigationTitle("Suche")
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Suche nach Tags...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject private var authService: MainAuthServiceProtocol
    
    var body: some View {
        NavigationView {
            VStack {
                if let user = authService.currentUser {
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                        
                        Text(user.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Score: \(user.score)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Abmelden") {
                            Task {
                                await authService.logout()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                } else {
                    Text("Benutzer nicht gefunden")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profil")
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsServiceProtocol
    
    var body: some View {
        NavigationView {
            List {
                Section("Feed") {
                    Toggle("Videos stumm", isOn: $settings.isVideoMuted)
                    Toggle("SFW anzeigen", isOn: $settings.showSFW)
                    Toggle("NSFW anzeigen", isOn: $settings.showNSFW)
                    Toggle("NSFL anzeigen", isOn: $settings.showNSFL)
                    Toggle("POL anzeigen", isOn: $settings.showPOL)
                }
                
                Section("Anzeige") {
                    Picker("Farbschema", selection: $settings.colorSchemeSetting) {
                        ForEach(ColorSchemeSetting.allCases) { scheme in
                            Text(scheme.displayName).tag(scheme)
                        }
                    }
                    
                    Picker("Gittergröße", selection: $settings.gridSize) {
                        ForEach(GridSizeSetting.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                }
                
                Section("Cache") {
                    HStack {
                        Text("Bild-Cache")
                        Spacer()
                        Text("\(String(format: "%.1f", settings.currentImageDataCacheSizeMB)) MB")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Daten-Cache")
                        Spacer()
                        Text("\(String(format: "%.1f", settings.currentDataCacheSizeMB)) MB")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

// MARK: - Supporting Types
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

struct UserInfo: Codable, Hashable {
    let id: Int
    let name: String
    let registered: Int
    let score: Int
    let mark: Int
    let badges: [ApiBadge]?
    let collections: [ApiCollection]?
}

struct ApiBadge: Codable, Identifiable, Hashable {
    var id: String { image }
    let image: String
    let description: String?
    let created: Int?
    let link: String?
    let category: String?
}

struct ApiCollection: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let keyword: String?
    let isPublic: Int
    let isDefault: Int
    let itemCount: Int
}

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

struct LoginResponse: Codable {
    let success: Bool
    let error: String?
    let ban: BanInfo?
    let nonce: NonceInfo?
}

struct BanInfo: Codable {
    let banned: Bool
    let reason: String
    let till: Int?
    let userId: Int?
}

struct NonceInfo: Codable {
    let nonce: String
}