import Foundation
import Combine
import os
import Kingfisher
import SwiftUI

// MARK: - Simplified App Settings (KISS + YAGNI)
@MainActor
class AppSettings: ObservableObject, SettingsServiceProtocol {
    
    // MARK: - Dependencies
    private nonisolated static let logger = LoggerFactory.create(for: AppSettings.self)
    private let cacheService: CacheServiceProtocol
    
    // MARK: - UserDefaults Properties (using Property Wrappers)
    @UserDefaultPublished(key: "isVideoMutedPreference_v1", defaultValue: true)
    var isVideoMuted: Bool
    
    @UserDefaultPublished(key: "feedTypePreference_v1", defaultValue: FeedType.promoted.rawValue)
    private var _feedTypeRawValue: Int
    
    @UserDefaultPublished(key: "showSFWPreference_v1", defaultValue: true)
    var showSFW: Bool {
        didSet {
            if isUserLoggedInForApiFlags && feedType != .junk {
                self.showNSFP = showSFW
                AppSettings.logger.debug("showSFW changed to \(self.showSFW). Automatically set showNSFP to \(self.showNSFP) (logged in, not junk).")
            }
        }
    }
    
    @UserDefaultPublished(key: "showNSFWPreference_v1", defaultValue: false)
    var showNSFW: Bool
    
    @UserDefaultPublished(key: "showNSFLPreference_v1", defaultValue: false)
    var showNSFL: Bool
    
    @UserDefaultPublished(key: "showPOLPreference_v1", defaultValue: false)
    var showPOL: Bool
    
    @UserDefaultPublished(key: "maxImageCacheSizeMB_v1", defaultValue: 100)
    var maxImageCacheSizeMB: Int {
        didSet {
            updateKingfisherCacheLimit()
        }
    }
    
    @UserDefaultPublished(key: "commentSortOrder_v1", defaultValue: CommentSortOrder.date.rawValue)
    private var _commentSortOrderRawValue: Int
    
    @UserDefaultPublished(key: "hideSeenItems_v1", defaultValue: false)
    var hideSeenItems: Bool {
        didSet {
            Self.logger.info("Hide seen items setting changed to: \(self.hideSeenItems)")
        }
    }
    
    @UserDefaultPublished(key: "subtitleActivationMode_v1", defaultValue: SubtitleActivationMode.disabled.rawValue)
    private var _subtitleActivationModeRawValue: Int
    
    @UserDefaultOptional(key: "selectedCollectionIdForFavorites_v1")
    var selectedCollectionIdForFavorites: Int? {
        didSet {
            if let newId = selectedCollectionIdForFavorites {
                Self.logger.info("Selected Collection ID for Favorites changed to: \(newId)")
            } else {
                Self.logger.info("Selected Collection ID for Favorites cleared (set to nil).")
            }
        }
    }
    
    @UserDefaultPublished(key: "colorSchemeSetting_v1", defaultValue: ColorSchemeSetting.system.rawValue)
    private var _colorSchemeSettingRawValue: Int
    
    @UserDefaultPublished(key: "gridSizeSetting_v1", defaultValue: GridSizeSetting.small.rawValue)
    private var _gridSizeSettingRawValue: Int
    
    @UserDefaultPublished(key: "accentColorChoice_v1", defaultValue: AccentColorChoice.blue.rawValue)
    private var _accentColorChoiceRawValue: String
    
    @UserDefaultPublished(key: "forcePhoneLayoutOnPadAndMac_v1", defaultValue: false)
    var forcePhoneLayoutOnPadAndMac: Bool {
        didSet {
            Self.logger.info("Force phone layout on iPad/Mac setting changed to: \(self.forcePhoneLayoutOnPadAndMac)")
        }
    }
    
    // MARK: - Computed Properties
    var feedType: FeedType {
        get { FeedType(rawValue: _feedTypeRawValue) ?? .promoted }
        set { 
            _feedTypeRawValue = newValue.rawValue
            Self.logger.info("Feed type changed to: \(newValue.displayName)")
            if isUserLoggedInForApiFlags && newValue != .junk {
                self.showNSFP = self.showSFW
            }
        }
    }
    
    var commentSortOrder: CommentSortOrder {
        get { CommentSortOrder(rawValue: _commentSortOrderRawValue) ?? .date }
        set { 
            _commentSortOrderRawValue = newValue.rawValue
            Self.logger.info("Comment sort order changed to: \(newValue.displayName)")
        }
    }
    
    var subtitleActivationMode: SubtitleActivationMode {
        get { SubtitleActivationMode(rawValue: _subtitleActivationModeRawValue) ?? .disabled }
        set { 
            _subtitleActivationModeRawValue = newValue.rawValue
            Self.logger.info("Subtitle activation mode changed to: \(newValue.displayName)")
        }
    }
    
    var colorSchemeSetting: ColorSchemeSetting {
        get { ColorSchemeSetting(rawValue: _colorSchemeSettingRawValue) ?? .system }
        set { 
            _colorSchemeSettingRawValue = newValue.rawValue
            Self.logger.info("Color scheme setting changed to: \(newValue.displayName)")
        }
    }
    
    var gridSize: GridSizeSetting {
        get { GridSizeSetting(rawValue: _gridSizeSettingRawValue) ?? .small }
        set { 
            _gridSizeSettingRawValue = newValue.rawValue
            Self.logger.info("Grid size setting changed to: \(newValue.displayName) (rawValue: \(newValue.rawValue))")
        }
    }
    
    var accentColorChoice: AccentColorChoice {
        get { AccentColorChoice(rawValue: _accentColorChoiceRawValue) ?? .blue }
        set { 
            _accentColorChoiceRawValue = newValue.rawValue
            Self.logger.info("Accent color choice changed to: \(newValue.displayName)")
        }
    }
    
    // MARK: - API Flags (Computed)
    private var _isUserLoggedInForApiFlags: Bool = false
    private let flagAccessQueue = DispatchQueue(label: "com.aetherium.Pr0gramm.flagAccessQueue")
    
    var apiFlags: Int {
        let loggedIn = flagAccessQueue.sync { _isUserLoggedInForApiFlags }
        
        if !loggedIn {
            return 1
        }
        
        if feedType == .junk {
            var flags = 0
            if showSFW { flags |= 1 }
            if showNSFW { flags |= 2 }
            if showNSFL { flags |= 4 }
            if showPOL { flags |= 16 }
            return flags == 0 ? 1 : flags
        } else {
            var flags = 0
            if showSFW { flags |= 1 }
            if showNSFW { flags |= 2 }
            if showNSFL { flags |= 4 }
            if showPOL { flags |= 16 }
            return flags == 0 ? 1 : flags
        }
    }
    
    var apiPromoted: Int? {
        switch feedType {
        case .new: return 0
        case .promoted: return 1
        case .junk: return nil
        }
    }
    
    var apiShowJunk: Bool {
        return feedType == .junk
    }
    
    // MARK: - Published Properties for UI
    @Published var currentImageDataCacheSizeMB: Double = 0.0
    @Published var currentDataCacheSizeMB: Double = 0.0
    @Published private(set) var seenItemIDs: Set<Int> = []
    
    // MARK: - Cache Keys
    private static let localSeenItemsCacheKey = "seenItems_v1"
    
    // MARK: - Initialization
    init(cacheService: CacheServiceProtocol) {
        self.cacheService = cacheService
        Self.logger.info("AppSettings initializing...")
        loadSeenItemIDs()
        updateCacheSizes()
        Self.logger.info("AppSettings initialization completed.")
    }
    
    // MARK: - Public Methods
    func updateUserLoginStatusForApiFlags(isLoggedIn: Bool) {
        let oldLoginStatus = flagAccessQueue.sync { _isUserLoggedInForApiFlags }
        flagAccessQueue.sync {
            _isUserLoggedInForApiFlags = isLoggedIn
        }
        Self.logger.info("User login status for API flags updated to: \(isLoggedIn)")
        
        if oldLoginStatus != isLoggedIn {
            if isLoggedIn && self.feedType != .junk {
                self.showNSFP = self.showSFW
            } else if !isLoggedIn {
                self.showNSFP = self.showSFW
            }
        }
    }
    
    func markItemAsSeen(id: Int) {
        guard !seenItemIDs.contains(id) else {
            Self.logger.trace("Item \(id) was already marked as seen")
            return
        }
        
        seenItemIDs.insert(id)
        Self.logger.debug("Marked item \(id) as seen. Total seen: \(seenItemIDs.count)")
        saveSeenItemIDs()
    }
    
    func markItemsAsSeen(ids: Set<Int>) {
        let newIDs = ids.subtracting(seenItemIDs)
        guard !newIDs.isEmpty else {
            Self.logger.trace("No new items to mark as seen")
            return
        }
        
        seenItemIDs.formUnion(newIDs)
        Self.logger.info("Marked \(newIDs.count) items as seen. Total seen: \(seenItemIDs.count)")
        saveSeenItemIDs()
    }
    
    func clearSeenItemsCache() async {
        Self.logger.warning("Clearing seen items cache")
        seenItemIDs = []
        await cacheService.clear(forKey: Self.localSeenItemsCacheKey)
    }
    
    func updateCacheSizes() async {
        Self.logger.debug("Updating cache sizes")
        await updateDataCacheSize()
        await updateImageCacheSize()
    }
    
    // MARK: - Private Methods
    private func loadSeenItemIDs() {
        Task {
            if let cachedIDs: Set<Int> = await cacheService.load(forKey: Self.localSeenItemsCacheKey) {
                await MainActor.run {
                    self.seenItemIDs = cachedIDs
                }
                Self.logger.info("Loaded \(cachedIDs.count) seen item IDs from cache")
            } else {
                await MainActor.run {
                    self.seenItemIDs = []
                }
                Self.logger.info("No seen item IDs found in cache")
            }
        }
    }
    
    private func saveSeenItemIDs() {
        Task {
            await cacheService.save(seenItemIDs, forKey: Self.localSeenItemsCacheKey)
        }
    }
    
    private func updateDataCacheSize() async {
        // Implementation for data cache size update
        await MainActor.run {
            self.currentDataCacheSizeMB = 0.0 // Placeholder
        }
    }
    
    private func updateImageCacheSize() async {
        // Implementation for image cache size update
        await MainActor.run {
            self.currentImageDataCacheSizeMB = 0.0 // Placeholder
        }
    }
    
    private func updateKingfisherCacheLimit() {
        let maxBytes = Int64(maxImageCacheSizeMB) * 1024 * 1024
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = maxBytes
        Self.logger.info("Updated Kingfisher cache limit to \(maxImageCacheSizeMB) MB")
    }
}

// MARK: - Supporting Enums
enum FeedType: Int, CaseIterable, Identifiable {
    case new = 0
    case promoted = 1
    case junk = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .new: return "Neu"
        case .promoted: return "Beliebt"
        case .junk: return "Müll"
        }
    }
}

enum CommentSortOrder: Int, CaseIterable, Identifiable {
    case date = 0
    case score = 1
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .date: return "Datum / Zeit"
        case .score: return "Benis (Score)"
        }
    }
}

enum SubtitleActivationMode: Int, CaseIterable, Identifiable {
    case disabled = 0
    case alwaysOn = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .disabled: return "Deaktiviert"
        case .alwaysOn: return "Aktiviert"
        }
    }
}

enum ColorSchemeSetting: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Systemeinstellung"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
    
    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum GridSizeSetting: Int, CaseIterable, Identifiable {
    case small = 3
    case medium = 4
    case large = 5
    
    var id: Int { rawValue }
    
    var displayName: String {
        return "\(rawValue)"
    }
    
    func columns(for horizontalSizeClass: UserInterfaceSizeClass?, isMac: Bool) -> Int {
        let baseCount = rawValue
        if isMac {
            return baseCount + 2
        } else {
            if horizontalSizeClass == .regular {
                return baseCount + 1
            } else {
                return baseCount
            }
        }
    }
}

enum AccentColorChoice: String, CaseIterable, Identifiable {
    case orange = "Bewährtes Orange"
    case green = "Angenehmes Grün"
    case olive = "Olivgrün des Friedens"
    case blue = "Episches Blau"
    case pink = "Altes Pink"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var swiftUIColor: Color {
        switch self {
        case .orange: return Color(hex: 0xee4d2e)
        case .green: return Color(hex: 0x64b944)
        case .olive: return Color(hex: 0x827717)
        case .blue: return Color(hex: 0x008FFF)
        case .pink: return Color(hex: 0xc2185b)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}