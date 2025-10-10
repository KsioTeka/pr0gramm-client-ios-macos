import Foundation

// MARK: - Cache Service (SRP: Only handles caching)
class CacheService: CacheServiceProtocol {
    
    // MARK: - Dependencies
    private let logger: LoggerProtocol
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSizeBytes: Int64 = 50 * 1024 * 1024 // 50 MB
    
    // MARK: - Initialization
    init(logger: LoggerProtocol = LoggerFactory.create(for: Self.self)) {
        self.logger = logger
        
        guard let cacheBaseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Caches directory")
        }
        
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            fatalError("Could not retrieve Bundle Identifier")
        }
        
        self.cacheDirectory = cacheBaseURL.appendingPathComponent(bundleIdentifier + ".datadiskcache", isDirectory: true)
        createCacheDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    func save<T: Codable>(_ data: T, forKey key: String) async {
        guard let fileURL = getCacheFileURL(forKey: key) else {
            logger.error("Could not create cache file URL for key: \(key)")
            return
        }
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: fileURL, options: .atomic)
            logger.debug("Successfully saved data for key: \(key)")
            await enforceSizeLimit()
        } catch {
            logger.error("Failed to save data for key \(key): \(error.localizedDescription)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        guard let fileURL = getCacheFileURL(forKey: key) else {
            logger.error("Could not create cache file URL for key: \(key)")
            return nil
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("Cache file not found for key: \(key)")
            return nil
        }
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let decodedData = try JSONDecoder().decode(type, from: fileData)
            updateFileAccessDate(for: fileURL)
            logger.debug("Successfully loaded data for key: \(key)")
            return decodedData
        } catch {
            logger.error("Failed to load data for key \(key): \(error.localizedDescription)")
            await clear(forKey: key)
            return nil
        }
    }
    
    func clear(forKey key: String) async {
        guard let fileURL = getCacheFileURL(forKey: key) else {
            logger.error("Could not create cache file URL for key: \(key)")
            return
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("Cache file does not exist for key: \(key)")
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
            logger.debug("Successfully cleared cache for key: \(key)")
        } catch {
            logger.error("Failed to clear cache for key \(key): \(error.localizedDescription)")
        }
    }
    
    func clearAll() async {
        logger.warning("Clearing all cache files")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            let cacheFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            for fileURL in cacheFiles {
                try fileManager.removeItem(at: fileURL)
            }
            
            logger.info("Cleared \(cacheFiles.count) cache files")
        } catch {
            logger.error("Failed to clear all cache files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    private func createCacheDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: cacheDirectory.path) else {
            logger.debug("Cache directory already exists")
            return
        }
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            logger.info("Successfully created cache directory")
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
    }
    
    private func getCacheFileURL(forKey key: String) -> URL? {
        let sanitizedKey = key.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        guard !sanitizedKey.isEmpty else {
            logger.error("Sanitized key is empty for original key: \(key)")
            return nil
        }
        
        let fileName = "\(sanitizedKey).json"
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    private func updateFileAccessDate(for fileURL: URL) {
        do {
            let attributes = [FileAttributeKey.modificationDate: Date()]
            try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
        } catch {
            logger.warning("Failed to update access date for file: \(fileURL.lastPathComponent)")
        }
    }
    
    private func enforceSizeLimit() async {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            let cacheFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            var totalSize: Int64 = 0
            var filesWithInfo: [(url: URL, size: Int64, date: Date)] = []
            
            for fileURL in cacheFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let modDate = attributes[.modificationDate] as? Date ?? Date.distantPast
                
                totalSize += fileSize
                filesWithInfo.append((url: fileURL, size: fileSize, date: modDate))
            }
            
            if totalSize > maxCacheSizeBytes {
                logger.info("Cache size limit exceeded. Starting cleanup")
                
                // Sort by date (oldest first)
                filesWithInfo.sort { $0.date < $1.date }
                
                var removedCount = 0
                var sizeReduced: Int64 = 0
                
                for fileInfo in filesWithInfo {
                    if totalSize <= maxCacheSizeBytes { break }
                    
                    // Skip seen items cache
                    if fileInfo.url.lastPathComponent.hasPrefix("seenItems_") {
                        continue
                    }
                    
                    try fileManager.removeItem(at: fileInfo.url)
                    totalSize -= fileInfo.size
                    sizeReduced += fileInfo.size
                    removedCount += 1
                }
                
                logger.info("Cache cleanup completed. Removed \(removedCount) files, reduced size by \(sizeReduced / (1024 * 1024)) MB")
            }
        } catch {
            logger.error("Failed to enforce cache size limit: \(error.localizedDescription)")
        }
    }
}