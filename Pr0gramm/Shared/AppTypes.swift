import Foundation
import SwiftUI

// MARK: - App Types for State of the Art Architecture

// MARK: - Login Request
struct LoginRequest {
    let username: String
    let password: String
    let captcha: String?
    let token: String?
}

// MARK: - Feed Type
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

// MARK: - Comment Sort Order
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

// MARK: - Subtitle Activation Mode
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

// MARK: - Color Scheme Setting
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

// MARK: - Grid Size Setting
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

// MARK: - Accent Color Choice
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