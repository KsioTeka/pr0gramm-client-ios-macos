# kickstart_variables

## project_goal
- Native SwiftUI client for pr0gramm.com delivering fast browsing experience on iOS and macOS.

## codebase_root
- Pr0gramm

## tech_stack
- Swift 5.9
- SwiftUI
- Combine
- URLSession-based networking
- Xcode project with iOS and macOS targets

## known_issues
- Automated test coverage is absent; XCTest targets are missing.
- Networking layer responsibilities overlap across Services and Features modules without explicit boundaries.
- Legacy settings implementation (`AppSettings_Old.swift`) remains in repository alongside current settings.

## constraints
- Targets iOS 17 and macOS 14 devices with Apple Silicon per current SwiftUI focus.
- Depends on pr0gramm.com REST endpoints; availability and rate limits influence reliability.
- Build and distribution performed through Xcode; CI configuration presently unspecified.

## priorities
1. Establish automated test targets to enable regression coverage.
2. Clarify networking architecture boundaries and document responsibilities.
3. Remove or migrate legacy settings implementation to reduce confusion.
