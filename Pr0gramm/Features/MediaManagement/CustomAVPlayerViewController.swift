// Pr0gramm/Pr0gramm/Features/MediaManagement/CustomAVPlayerViewController.swift
// --- START OF COMPLETE FILE ---

import AVKit
import UIKit
import os

/// Custom `AVPlayerViewController` that forwards arrow key presses and exposes fullscreen callbacks.
class CustomAVPlayerViewController: AVPlayerViewController, AVPlayerViewControllerDelegate {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Pr0gramm",
        category: "CustomAVPlayerViewController"
    )

    var actionHandler: KeyboardActionHandler?

    var willBeginFullScreen: (() -> Void)?
    var willEndFullScreen: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        showsPlaybackControls = true
        Self.logger.debug("viewDidLoad - delegate assigned, playback controls enabled")
    }

    override var keyCommands: [UIKeyCommand]? {
        let nonArrowCommands = (super.keyCommands ?? []).filter { command in
            guard let input = command.input else { return true }
            return input != UIKeyCommand.inputLeftArrow &&
                   input != UIKeyCommand.inputRightArrow &&
                   input != UIKeyCommand.inputUpArrow &&
                   input != UIKeyCommand.inputDownArrow
        }
        Self.logger.trace("Filtered KeyCommands: \(nonArrowCommands.compactMap { $0.input })")
        return nonArrowCommands
    }

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Self.logger.debug("viewWillDisappear")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Self.logger.debug("viewWillAppear")
    }

    // MARK: - AVPlayerViewControllerDelegate

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        Self.logger.debug("Delegate: willBeginFullScreenPresentation")
        willBeginFullScreen?()
        Self.logger.debug("No explicit pause triggered for fullscreen entry")
    }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        Self.logger.debug("Delegate: willEndFullScreenPresentation - coordinating animation")
        coordinator.animate(
            alongsideTransition: nil,
            completion: { [weak self] (_: UIViewControllerTransitionCoordinatorContext) in
                guard let self else { return }
                Self.logger.debug("Delegate: willEndFullScreenPresentation - animation complete")
                self.willEndFullScreen?()
            }
        )
    }

    deinit {
        Self.logger.debug("deinit")
    }
}
// --- END OF COMPLETE FILE ---
