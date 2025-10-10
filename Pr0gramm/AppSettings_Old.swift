// Pr0gramm/Pr0gramm/AppSettings.swift
// --- START OF COMPLETE FILE ---

import Foundation
import Combine
import os
import Kingfisher
import CloudKit
import SwiftUI
import BackgroundTasks
import UserNotifications

enum BackgroundFetchInterval: Int, CaseIterable, Identifiable {
    case minutes30 = 1800 // 30 * 60
    case minutes60 = 3600 // 60 * 60
    case hours2 = 7200    // 2 * 3600
    case hours4 = 14400   // 4 * 3600
    case hours6 = 21600   // 6 * 3600
    case hours12 = 43200  // 12 * 3600

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .minutes30: return "30 Minuten"
        case .minutes60: return "1 Stunde"
        case .hours2: return "2 Stunden"
        case .hours4: return "4 Stunden"
        case .hours6: return "6 Stunden"
        case .hours12: return "12 Stunden"
        }
    }

    var timeInterval: TimeInterval {
        return TimeInterval(self.rawValue)
    }
}

enum FeedType: Int, CaseIterable, Identifiable {
    case new = 0
    case promoted = 1
    case junk = 2

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .new: return "Neu"
        case .promoted: return "Beliebt"
        case .junk: return "Müll"
        }
    }
}

enum CommentSortOrder: Int, CaseIterable, Identifiable {
    case date = 0, score = 1
    var id: Int { self.rawValue }
    var displayName: String {
        switch self { case .date: return "Datum / Zeit"; case .score: return "Benis (Score)"}
    }
}

enum SubtitleActivationMode: Int, CaseIterable, Identifiable {
    case disabled = 0
    case alwaysOn = 2
    var id: Int { self.rawValue }
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

    var id: Int { self.rawValue }

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

    var id: Int { self.rawValue }

    var displayName: String {
        return "\(self.rawValue)"
    }

    func columns(for horizontalSizeClass: UserInterfaceSizeClass?, isMac: Bool) -> Int {
        let baseCount = self.rawValue
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

    var id: String { self.rawValue }
    var displayName: String { self.rawValue }

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


@MainActor
class AppSettings: ObservableObject {

    private nonisolated static let logger = LoggerFactory.create(for: AppSettings.self)
    private let cacheService: CacheServiceProtocol


    // Cache keys
    private static let localSeenItemsCacheKey = "seenItems_v1"

    @UserDefaultPublished(key: "isVideoMutedPreference_v1", defaultValue: true)
    var isVideoMuted: Bool
    @UserDefaultPublished(key: "feedTypePreference_v1", defaultValue: FeedType.promoted.rawValue)
    private var _feedTypeRawValue: Int
    
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
    @UserDefaultPublished(key: "showNSFPPreference_v1", defaultValue: true)
    var showNSFP: Bool {
        didSet {
            AppSettings.logger.debug("showNSFP (internal state) changed to \(self.showNSFP).")
        }
    }
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
    
    var commentSortOrder: CommentSortOrder {
        get { CommentSortOrder(rawValue: _commentSortOrderRawValue) ?? .date }
        set { 
            _commentSortOrderRawValue = newValue.rawValue
            Self.logger.info("Comment sort order changed to: \(newValue.displayName)")
        }
    }
    
    @UserDefaultPublished(key: "hideSeenItems_v1", defaultValue: false)
    var hideSeenItems: Bool {
        didSet {
            Self.logger.info("Hide seen items setting changed to: \(self.hideSeenItems)")
        }
    }

    @UserDefaultPublished(key: "subtitleActivationMode_v1", defaultValue: SubtitleActivationMode.disabled.rawValue)
    private var _subtitleActivationModeRawValue: Int
    
    var subtitleActivationMode: SubtitleActivationMode {
        get { SubtitleActivationMode(rawValue: _subtitleActivationModeRawValue) ?? .disabled }
        set { 
            _subtitleActivationModeRawValue = newValue.rawValue
            Self.logger.info("Subtitle activation mode changed to: \(newValue.displayName)")
        }
    }
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
    
    var colorSchemeSetting: ColorSchemeSetting {
        get { ColorSchemeSetting(rawValue: _colorSchemeSettingRawValue) ?? .system }
        set { 
            _colorSchemeSettingRawValue = newValue.rawValue
            Self.logger.info("Color scheme setting changed to: \(newValue.displayName)")
        }
    }
    
    @UserDefaultPublished(key: "gridSizeSetting_v1", defaultValue: GridSizeSetting.small.rawValue)
    private var _gridSizeSettingRawValue: Int
    
    var gridSize: GridSizeSetting {
        get { GridSizeSetting(rawValue: _gridSizeSettingRawValue) ?? .small }
        set { 
            _gridSizeSettingRawValue = newValue.rawValue
            Self.logger.info("Grid size setting changed to: \(newValue.displayName) (rawValue: \(newValue.rawValue))")
        }
    }
    
    // Startup filters removed - YAGNI principle

    @UserDefaultPublished(key: "accentColorChoice_v1", defaultValue: AccentColorChoice.blue.rawValue)
    private var _accentColorChoiceRawValue: String
    
    var accentColorChoice: AccentColorChoice {
        get { AccentColorChoice(rawValue: _accentColorChoiceRawValue) ?? .blue }
        set { 
            _accentColorChoiceRawValue = newValue.rawValue
            Self.logger.info("Accent color choice changed to: \(newValue.displayName)")
        }
    }
    
    // Experimental features removed - YAGNI principle

    // Background tasks removed - YAGNI principle

    @UserDefaultPublished(key: "forcePhoneLayoutOnPadAndMac_v1", defaultValue: false)
    var forcePhoneLayoutOnPadAndMac: Bool {
        didSet {
            Self.logger.info("Force phone layout on iPad/Mac setting changed to: \(self.forcePhoneLayoutOnPadAndMac)")
        }
    }


    @Published var transientSessionMuteState: Bool? = nil
    @Published var currentImageDataCacheSizeMB: Double = 0.0
    @Published var currentDataCacheSizeMB: Double = 0.0
    @Published private(set) var seenItemIDs: Set<Int> = []

    private var saveSeenItemsTask: Task<Void, Never>?
    private let saveSeenItemsDebounceDelay: Duration = .seconds(1)

    var favoritesSettingsChangedPublisher: AnyPublisher<Void, Never> {
        let sfwPublisher = $showSFW.map { _ in () }.eraseToAnyPublisher()
        let nsfwPublisher = $showNSFW.map { _ in () }.eraseToAnyPublisher()
        let nsflPublisher = $showNSFL.map { _ in () }.eraseToAnyPublisher()
        let nsfpPublisher = $showNSFP.map { _ in () }.eraseToAnyPublisher()
        let polPublisher = $showPOL.map { _ in () }.eraseToAnyPublisher()
        let collectionIdPublisher = $selectedCollectionIdForFavorites.map { _ in () }.eraseToAnyPublisher()

        return Publishers.MergeMany([
            sfwPublisher,
            nsfwPublisher,
            nsflPublisher,
            nsfpPublisher,
            polPublisher,
            collectionIdPublisher
        ])
        .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }


    private var _isUserLoggedInForApiFlags: Bool = false
    private let flagAccessQueue = DispatchQueue(label: "com.aetherium.Pr0gramm.flagAccessQueue")

    public func updateUserLoginStatusForApiFlags(isLoggedIn: Bool) {
        let oldLoginStatus = self._isUserLoggedInForApiFlags
        flagAccessQueue.sync {
            self._isUserLoggedInForApiFlags = isLoggedIn
        }
        AppSettings.logger.info("User login status for API flags calculation updated to: \(isLoggedIn)")
        
        if oldLoginStatus != isLoggedIn {
            if isLoggedIn && self.feedType != .junk {
                self.showNSFP = self.showSFW
            } else if !isLoggedIn {
                self.showNSFP = self.showSFW
            }
        }
    }

    private var isUserLoggedInForApiFlags: Bool {
        flagAccessQueue.sync {
            return self._isUserLoggedInForApiFlags
        }
    }

    var apiFlags: Int {
        get {
            let loggedIn = self.isUserLoggedInForApiFlags

            if !loggedIn {
                return 1
            }

            if feedType == .junk {
                var flags = 0
                if showSFW { flags |= 1 }
                if showNSFP { flags |= 8 }
                return flags == 0 ? 1 : flags
            } else {
                var flags = 0
                if showSFW {
                    flags |= 1
                    flags |= 8
                }
                if showNSFW {
                    flags |= 2
                }
                if showNSFL {
                    flags |= 4
                }
                if showPOL {
                    flags |= 16
                }
                return flags == 0 ? 1 : flags
            }
        }
    }


    var apiPromoted: Int? {
        get {
            switch feedType {
            case .new: return 0
            case .promoted: return 1
            case .junk: return nil
            }
        }
    }

    var apiShowJunk: Bool {
        return feedType == .junk
    }

    var hasActiveContentFilter: Bool {
        if isUserLoggedInForApiFlags {
            if feedType == .junk {
                return showSFW || showNSFP
            } else {
                return showSFW || showNSFW || showNSFL || showPOL
            }
        } else {
            return showSFW
        }
    }

    init(cacheService: CacheServiceProtocol) {
        self.cacheService = cacheService
        Self.logger.info("AppSettings initializing...")
        loadSeenItemIDs()
        updateCacheSizes()
        Self.logger.info("AppSettings initialization completed.")
    }
    
    /// Cycles through the available subtitle activation modes.
    func cycleSubtitleMode() {
        switch self.subtitleActivationMode {
        case .disabled:
            self.subtitleActivationMode = .alwaysOn
        case .alwaysOn:
            self.subtitleActivationMode = .disabled
        }
    }


    func clearSeenItemsCache() async {
        Self.logger.warning("Clearing Seen Items Cache (Local & iCloud) requested.")
        await MainActor.run {
            self.seenItemIDs = []
        }
        Self.logger.info("Cleared in-memory seen items set.")
        
        Task.detached { [cacheService = self.cacheService, cloudStore = self.cloudStore] in
            await cacheService.clearCache(forKey: Self.localSeenItemsCacheKey)
            Self.logger.info("Cleared local seen items cache file via CacheService (background).")
            
            cloudStore.removeObject(forKey: Self.iCloudSeenItemsKey)
            let syncSuccess = cloudStore.synchronize()
            Self.logger.info("Removed seen items key from iCloud KVS. Synchronize requested: \(syncSuccess) (background).")
        }
    }
    func clearAllAppCache() async {
        Self.logger.warning("Clearing ALL Data Cache, Kingfisher Image Cache, Seen Items Cache (Local & iCloud) requested.")
        await cacheService.clearAllDataCache()
        await clearSeenItemsCache()
        let logger = Self.logger
        KingfisherManager.shared.cache.clearDiskCache {
            logger.info("Kingfisher disk cache clearing finished.")
            Task { await self.updateCacheSizes() }
        }
        await updateCacheSizes()
    }
    func updateCacheSizes() async {
        Self.logger.debug("Updating both image and data cache sizes...")
        await updateDataCacheSize()
        await updateImageDataCacheSize()
    }
    private func updateDataCacheSize() async {
        let dataSizeBytes = await cacheService.getCurrentDataCacheTotalSize()
        let dataSizeMB = Double(dataSizeBytes) / (1024.0 * 1024.0)
        self.currentDataCacheSizeMB = dataSizeMB
        Self.logger.info("Updated currentDataCacheSizeMB to: \(String(format: "%.2f", dataSizeMB)) MB")
    }
    private func updateImageDataCacheSize() async {
        let logger = Self.logger
        let imageSizeBytes: UInt = await withCheckedContinuation { continuation in
            KingfisherManager.shared.cache.calculateDiskStorageSize { result in
                switch result {
                case .success(let size): continuation.resume(returning: size)
                case .failure(let error): logger.error("Failed to calculate Kingfisher disk cache size: \(error.localizedDescription)"); continuation.resume(returning: 0)
                }
            }
        }
        let imageSizeMB = Double(imageSizeBytes) / (1024.0 * 1024.0)
        self.currentImageDataCacheSizeMB = imageSizeMB
        Self.logger.info("Updated currentImageDataCacheSizeMB to: \(String(format: "%.2f", imageSizeMB)) MB")
    }
    private func updateKingfisherCacheLimit() {
        let limitBytes = UInt(self.maxImageCacheSizeMB) * 1024 * 1024
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = limitBytes
        Self.logger.info("Set Kingfisher (image) disk cache size limit to \(limitBytes) bytes (\(self.maxImageCacheSizeMB) MB).")
    }

    func saveItemsToCache(_ items: [Item], forKey cacheKey: String) async {
        guard !cacheKey.isEmpty else { return }
        await cacheService.saveItems(items, forKey: cacheKey)
        await updateDataCacheSize()
    }
    func loadItemsFromCache(forKey cacheKey: String) async -> [Item]? {
         guard !cacheKey.isEmpty else { return nil }
         return await cacheService.loadItems(forKey: cacheKey)
    }
    func clearFavoritesCache(username: String?, collectionId: Int?) async {
        guard let user = username, let colId = collectionId else {
            Self.logger.warning("Cannot clear favorites cache: username or collectionId is nil.")
            return
        }
        let cacheKey = "favorites_\(user.lowercased())_collection_\(colId)"
        Self.logger.info("Clearing favorites data cache requested via AppSettings for key: \(cacheKey).")
        await cacheService.clearCache(forKey: cacheKey)
        await updateDataCacheSize()
    }

    func markItemAsSeen(id: Int) {
        guard !seenItemIDs.contains(id) else {
            Self.logger.trace("Item \(id) was already marked as seen (in-memory).")
            return
        }
        
        var updatedIDs = seenItemIDs
        updatedIDs.insert(id)
        seenItemIDs = updatedIDs
        Self.logger.debug("Marked item \(id) as seen (in-memory). Total seen: \(self.seenItemIDs.count). Scheduling save.")

        scheduleSaveSeenItems()
    }

    func markItemsAsSeen(ids: Set<Int>) {
        let newIDs = ids.subtracting(seenItemIDs)
        guard !newIDs.isEmpty else {
            Self.logger.trace("No new items to mark as seen from the provided batch.")
            return
        }
        
        Self.logger.debug("Marking \(newIDs.count) new items as seen (in-memory).")
        var idsToUpdate = seenItemIDs
        idsToUpdate.formUnion(newIDs)
        seenItemIDs = idsToUpdate
        Self.logger.info("Marked \(newIDs.count) items as seen (in-memory). Total seen: \(self.seenItemIDs.count). Scheduling save.")
        
        scheduleSaveSeenItems()
    }
    
    private func scheduleSaveSeenItems() {
        saveSeenItemsTask?.cancel()
        
        let idsToSave = self.seenItemIDs
        
        saveSeenItemsTask = Task {
            do {
                try await Task.sleep(for: saveSeenItemsDebounceDelay)
                guard !Task.isCancelled else {
                    Self.logger.info("Debounced save task for seen items cancelled during sleep.")
                    return
                }
                Task.detached(priority: .utility) { [weak self] in
                    guard let self = self else { return }
                    await self.performActualSaveOfSeenIDs(ids: idsToSave)
                }
            } catch is CancellationError {
                Self.logger.info("Debounced save task (scheduling part) cancelled.")
            } catch {
                Self.logger.error("Error in debounced save task scheduling: \(error.localizedDescription)")
            }
        }
    }

    public func forceSaveSeenItems() async {
        saveSeenItemsTask?.cancel()
        Self.logger.info("Force save seen items requested. Current debounced task (if any) cancelled.")
        let currentIDsToSave = self.seenItemIDs
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            await self.performActualSaveOfSeenIDs(ids: currentIDsToSave)
        }
    }

    private func performActualSaveOfSeenIDs(ids: Set<Int>) async {
        Self.logger.debug("BG Save: Saving \(ids.count) seen item IDs to local cache...")
        await cacheService.saveSeenIDs(ids, forKey: Self.localSeenItemsCacheKey)

        Self.logger.debug("BG Save: Saving \(ids.count) seen item IDs to iCloud KVS...")
        do {
            let data = try JSONEncoder().encode(ids)
            self.cloudStore.set(data, forKey: Self.iCloudSeenItemsKey)
            let syncSuccess = self.cloudStore.synchronize()
            Self.logger.info("BG Save: Saved seen IDs to iCloud KVS. Synchronize requested: \(syncSuccess).")
        } catch {
            Self.logger.error("BG Save: Failed to encode or save seen IDs to iCloud KVS: \(error.localizedDescription)")
        }
    }


    private func loadSeenItemIDs() async {
        Self.logger.debug("Loading seen item IDs (iCloud first, then local cache)...")
        var loadedFromCloud = false
        
        if let cloudData = cloudStore.data(forKey: Self.iCloudSeenItemsKey) {
            Self.logger.debug("Found data in iCloud KVS for key \(Self.iCloudSeenItemsKey).")
            do {
                let decodedIDs = try JSONDecoder().decode(Set<Int>.self, from: cloudData)
                await MainActor.run { self.seenItemIDs = decodedIDs }
                loadedFromCloud = true
                Self.logger.info("Successfully loaded \(decodedIDs.count) seen item IDs from iCloud KVS.")
                Task.detached(priority: .background) { await self.cacheService.saveSeenIDs(decodedIDs, forKey: Self.localSeenItemsCacheKey) }
            } catch {
                Self.logger.error("Failed to decode seen item IDs from iCloud KVS data: \(error.localizedDescription). Falling back to local cache.")
            }
        } else {
            Self.logger.info("No data found in iCloud KVS for key \(Self.iCloudSeenItemsKey). Checking local cache...")
        }

        if !loadedFromCloud {
            if let localIDs = await cacheService.loadSeenIDs(forKey: Self.localSeenItemsCacheKey) {
                 await MainActor.run { self.seenItemIDs = localIDs }
                 Self.logger.info("Loaded \(localIDs.count) seen item IDs from LOCAL cache.")
                 Task.detached(priority: .background) {
                      Self.logger.info("Syncing locally loaded seen IDs UP to iCloud (using performActualSave).")
                      await self.performActualSaveOfSeenIDs(ids: localIDs)
                 }
            } else {
                Self.logger.warning("Could not load seen item IDs from iCloud or local cache. Starting with an empty set.")
                 await MainActor.run { self.seenItemIDs = [] }
            }
        }
    }

    private func setupCloudKitKeyValueStoreObserver() {
        if keyValueStoreChangeObserver != nil { NotificationCenter.default.removeObserver(keyValueStoreChangeObserver!); keyValueStoreChangeObserver = nil }
        keyValueStoreChangeObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloudStore, queue: .main) { [weak self, capturedCloudStore = self.cloudStore] notification in
            Task { @MainActor [weak self, capturedCloudStore] in
                await self?.handleCloudKitStoreChange(notification: notification, cloudStoreToUse: capturedCloudStore)
            }
        }
        let syncSuccess = cloudStore.synchronize(); Self.logger.info("Setup iCloud KVS observer. Initial synchronize requested: \(syncSuccess)")
    }

    private func handleCloudKitStoreChange(notification: Notification, cloudStoreToUse: NSUbiquitousKeyValueStore) async {
        Self.logger.info("Received iCloud KVS didChangeExternallyNotification.")
        guard let userInfo = notification.userInfo, let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { Self.logger.warning("Could not get change reason from KVS notification."); return }
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String], changedKeys.contains(Self.iCloudSeenItemsKey) else { Self.logger.debug("KVS change notification did not contain our key (\(Self.iCloudSeenItemsKey)). Ignoring."); return }
        Self.logger.info("Change detected for our key (\(Self.iCloudSeenItemsKey)) in iCloud KVS.")

        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            Self.logger.debug("Change reason: ServerChange or InitialSyncChange.")
            guard let cloudData = cloudStoreToUse.data(forKey: Self.iCloudSeenItemsKey) else {
                Self.logger.warning("Our key (\(Self.iCloudSeenItemsKey)) was reportedly changed, but no data found in KVS. Possibly deleted externally?")
                await MainActor.run { self.seenItemIDs = [] }
                await self.cacheService.clearCache(forKey: Self.localSeenItemsCacheKey)
                Self.logger.info("Cleared local seen items state because key was missing in iCloud after external change notification.")
                return
            }
            do {
                let incomingIDs = try JSONDecoder().decode(Set<Int>.self, from: cloudData); Self.logger.info("Successfully decoded \(incomingIDs.count) seen IDs from external iCloud KVS change.")
                let localIDs = self.seenItemIDs; let mergedIDs = localIDs.union(incomingIDs)
                if mergedIDs.count > localIDs.count || mergedIDs != localIDs {
                    await MainActor.run { self.seenItemIDs = mergedIDs }
                    Self.logger.info("Merged external seen IDs. New total: \(mergedIDs.count).")
                    Task.detached(priority: .background) { await self.cacheService.saveSeenIDs(mergedIDs, forKey: Self.localSeenItemsCacheKey) }
                } else {
                    Self.logger.debug("Incoming seen IDs did not add new items or change the local set. No UI update needed.")
                }
            } catch { Self.logger.error("Failed to decode seen IDs from external iCloud KVS change data: \(error.localizedDescription)") }
        case NSUbiquitousKeyValueStoreAccountChange: Self.logger.warning("iCloud account changed. Reloading seen items state."); await loadSeenItemIDs()
        case NSUbiquitousKeyValueStoreQuotaViolationChange: Self.logger.error("iCloud KVS Quota Violation! Syncing might stop.")
        default: Self.logger.warning("Unhandled iCloud KVS change reason: \(changeReason)"); break
        }
    }

    deinit {
        if let observer = keyValueStoreChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            AppSettings.logger.debug("Removed iCloud KVS observer in deinit.")
        }
        saveSeenItemsTask?.cancel()
        AppSettings.logger.debug("Cancelled pending saveSeenItemsTask in deinit.")
    }
}
// --- END OF COMPLETE FILE ---
