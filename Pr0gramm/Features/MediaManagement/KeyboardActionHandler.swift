// Pr0gramm/Pr0gramm/Features/MediaManagement/KeyboardActionHandler.swift
// --- START OF COMPLETE FILE ---

import Foundation
import Combine
import os
import UIKit

/// Bridges keyboard arrow key events from UIKit controllers to closures that can be
/// configured by SwiftUI views or view models.
class KeyboardActionHandler: ObservableObject {
    enum NavigationAction: String, CaseIterable {
        case selectNext
        case selectPrevious
        case seekForward
        case seekBackward

        var logDescription: String {
            switch self {
            case .selectNext:
                return "Right arrow -> selectNextAction"
            case .selectPrevious:
                return "Left arrow -> selectPreviousAction"
            case .seekForward:
                return "Up arrow -> seekForwardAction"
            case .seekBackward:
                return "Down arrow -> seekBackwardAction"
            }
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Pr0gramm",
        category: "KeyboardActionHandler"
    )

    private static let disallowedModifiers: UIKeyModifierFlags = [.command, .alternate, .control, .shift]
    private static let keyMapping: [UIKeyboardHIDUsage: NavigationAction] = [
        .keyboardRightArrow: .selectNext,
        .keyboardLeftArrow: .selectPrevious,
        .keyboardUpArrow: .seekForward,
        .keyboardDownArrow: .seekBackward
    ]

    var selectNextAction: (() -> Void)?
    var selectPreviousAction: (() -> Void)?
    var seekForwardAction: (() -> Void)?
    var seekBackwardAction: (() -> Void)?

    @discardableResult
    func performAction(for key: UIKey) -> NavigationAction? {
        guard key.modifierFlags.intersection(Self.disallowedModifiers).isEmpty else {
            Self.logger.debug("Ignoring key due to unsupported modifier flags: \(key.modifierFlags.rawValue)")
            return nil
        }

        guard let action = Self.keyMapping[key.keyCode] else {
            return nil
        }

        guard let closure = closure(for: action) else {
            Self.logger.debug("\(action.rawValue) triggered without configured closure.")
            return nil
        }

        closure()
        return action
    }

    func handlePresses(_ presses: Set<UIPress>, logger: Logger) -> NavigationAction? {
        for press in presses {
            guard let key = press.key else { continue }
            logger.debug("Key pressed - HIDUsage: \(key.keyCode.rawValue), Modifiers: \(key.modifierFlags.rawValue)")

            if let action = performAction(for: key) {
                logger.debug("\(action.logDescription) triggered via pressesBegan.")
                return action
            }
        }

        return nil
    }

    private func closure(for action: NavigationAction) -> (() -> Void)? {
        switch action {
        case .selectNext:
            return selectNextAction
        case .selectPrevious:
            return selectPreviousAction
        case .seekForward:
            return seekForwardAction
        case .seekBackward:
            return seekBackwardAction
        }
    }
}
// --- END OF COMPLETE FILE ---
