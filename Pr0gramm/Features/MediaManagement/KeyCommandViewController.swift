// Pr0gramm/Pr0gramm/Features/MediaManagement/KeyCommandViewController.swift
// --- START OF COMPLETE FILE ---

import UIKit
import os

/// Captures keyboard events and forwards relevant arrow key presses to a `KeyboardActionHandler`.
class KeyCommandViewController: UIViewController {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Pr0gramm",
        category: "KeyCommandViewController"
    )

    var actionHandler: KeyboardActionHandler?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Self.logger.debug("viewDidAppear - requesting first responder status")
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let handler = actionHandler else {
            Self.logger.debug("No action handler configured, forwarding to super.pressesBegan")
            super.pressesBegan(presses, with: event)
            return
        }

        if handler.handlePresses(presses, logger: Self.logger) != nil {
            Self.logger.debug("Arrow key handled, skipping super.pressesBegan")
        } else {
            Self.logger.debug("No relevant arrow key detected, forwarding to super.pressesBegan")
            super.pressesBegan(presses, with: event)
        }
    }
}
// --- END OF COMPLETE FILE ---
