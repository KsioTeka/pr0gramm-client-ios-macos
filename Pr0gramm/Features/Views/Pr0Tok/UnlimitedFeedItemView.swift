// Pr0gramm/Pr0gramm/Features/Views/Pr0Tok/UnlimitedFeedItemView.swift
// --- START OF COMPLETE FILE ---

import SwiftUI
import os
import Kingfisher
import UIKit // Für UIPasteboard

fileprivate struct UnlimitedVotableTagView: View {
    let tag: ItemTag
    let currentVote: Int
    let isVoting: Bool
    let truncateText: Bool
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    let onTapTag: () -> Void

    @EnvironmentObject var authService: AuthService

    private let characterLimit = 10
    private var displayText: String {
        if truncateText && tag.tag.count > characterLimit {
            return String(tag.tag.prefix(characterLimit)) + "…"
        }
        return tag.tag
    }
    private let tagVoteButtonFont: Font = .caption

    var body: some View {
        HStack(spacing: 4) {
            if authService.isLoggedIn {
                Button(action: onDownvote) {
                    Image(systemName: currentVote == -1 ? "minus.circle.fill" : "minus.circle")
                        .font(tagVoteButtonFont)
                        .foregroundColor(currentVote == -1 ? .red : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(isVoting)
            }

            Text(displayText)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, authService.isLoggedIn ? 2 : 8)
                .padding(.vertical, 4)
                .contentShape(Capsule())
                .onTapGesture(perform: onTapTag)


            if authService.isLoggedIn {
                Button(action: onUpvote) {
                    Image(systemName: currentVote == 1 ? "plus.circle.fill" : "plus.circle")
                        .font(tagVoteButtonFont)
                        .foregroundColor(currentVote == 1 ? .green : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(isVoting)
            }
        }
        .padding(.horizontal, authService.isLoggedIn ? 6 : 0)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}


struct UnlimitedFeedItemView: View {
    let itemData: UnlimitedFeedItemDataModel
    @ObservedObject var playerManager: VideoPlayerManager
    @ObservedObject var keyboardActionHandlerForVideo: KeyboardActionHandler
    let isActive: Bool
    let isDummyItem: Bool

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var authService: AuthService
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UnlimitedFeedItemView")

    let onToggleShowAllTags: () -> Void
    let onUpvoteTag: (Int) -> Void
    let onDownvoteTag: (Int) -> Void
    let onTagTapped: (String) -> Void
    let onRetryLoadDetails: () -> Void
    let onShowAddTagSheet: () -> Void
    let onShowFullscreenImage: (Item) -> Void
    let onToggleFavorite: () -> Void
    let onShowCollectionSelection: () -> Void
    let onShareTapped: () -> Void
    let isProcessingFavorite: Bool
    let onShowUserProfile: (String) -> Void
    let onWillBeginFullScreenPr0Tok: () -> Void
    let onWillEndFullScreenPr0Tok: () -> Void
    let onUpvoteItem: () -> Void
    let onDownvoteItem: () -> Void
    let onWillPresentCommentSheet: () -> Void
    let onDidDismissCommentSheet: () -> Void


    var item: Item { itemData.item }
    
    @State private var showingCommentsSheet = false
    
    private let initialVisibleTagCountInItemView = 2
    
    private let bottomUIBarHeightEstimate: CGFloat = 70


    var body: some View {
        mediaContentLayer
            .contentShape(Rectangle())
            .onTapGesture {
                if item.isVideo {
                    Self.logger.trace("Media content (video) tapped, AVPlayerViewController should handle controls visibility.")
                } else if !isDummyItem {
                    Self.logger.trace("Media content (image) tapped, showing fullscreen.")
                    onShowFullscreenImage(item)
                }
            }
            .allowsHitTesting(!isDummyItem)
            .overlay(alignment: .bottom) {
                if !isDummyItem {
                    bottomControlsOverlay
                }
            }
            .overlay(alignment: .top) {
                 if isActive && item.isVideo && playerManager.playerItemID == item.id {
                    if let subtitleError = playerManager.subtitleError, !subtitleError.isEmpty {
                        VStack {
                            Text("Untertitel: \(subtitleError)")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(5)
                                .background(Material.ultraThin)
                                .cornerRadius(5)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.top, 50)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                 }
            }
            .overlay(alignment: .bottom) {
                 if isActive && item.isVideo && playerManager.playerItemID == item.id {
                    if let subtitle = playerManager.currentSubtitleText, !subtitle.isEmpty {
                        Text(subtitle)
                             .font(UIConstants.footnoteFont.weight(.medium))
                             .foregroundColor(.white)
                             .padding(.horizontal, 10)
                             .padding(.vertical, 5)
                             .background(.black.opacity(0.75))
                             .cornerRadius(6)
                             .multilineTextAlignment(.center)
                             .padding(.horizontal)
                             .padding(.bottom, bottomUIBarHeightEstimate + (bottomSafeAreaPadding > 0 ? bottomSafeAreaPadding : 10) + 10)
                             .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                             .id("pr0tok_subtitle_\(item.id)_\(subtitle)")
                             .allowsHitTesting(false)
                    }
                }
            }
            .background(Color.black)
            .clipped()
            .onChange(of: isActive) { oldValue, newValue in
                if isDummyItem { return }

                if newValue {
                    if item.isVideo {
                        if playerManager.playerItemID == item.id {
                            Self.logger.debug("UnlimitedFeedItemView: Item \(item.id) became active. Player exists. Requesting play.")
                            playerManager.requestPlay(for: item.id)
                        } else {
                            playerManager.setupPlayerIfNeeded(for: item, isFullscreen: false)
                            Self.logger.debug("UnlimitedFeedItemView: Item \(item.id) became active. Player setup initiated (shouldAutoplayWhenReady will be handled).")
                             Task {
                                 try? await Task.sleep(for: .milliseconds(50))
                                 playerManager.requestPlay(for: item.id)
                             }
                        }
                    }
                } else {
                    if item.isVideo && playerManager.playerItemID == item.id {
                         playerManager.player?.pause()
                         Self.logger.debug("UnlimitedFeedItemView: Player paused via isActive becoming false for item \(item.id)")
                    }
                }
            }
            .sheet(isPresented: $showingCommentsSheet, onDismiss: onDidDismissCommentSheet) {
                ItemCommentsSheetView(
                    itemId: itemData.item.id,
                    uploaderName: itemData.item.user,
                    initialComments: itemData.comments,
                    initialInfoStatusProp: itemData.itemInfoStatus,
                    onRetryLoadDetails: onRetryLoadDetails
                )
                .environmentObject(settings)
                .environmentObject(authService)
            }
    }

    @ViewBuilder
    private var bottomControlsOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.0)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("@\(item.user)")
                        .font(.headline).bold()
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .onTapGesture {
                            if !item.user.isEmpty {
                                Self.logger.info("Username '\(item.user)' tapped. Calling onShowUserProfile.")
                                onShowUserProfile(item.user)
                            }
                        }
                    
                    tagSection
                        .background(Color.clear)
                }
                .padding(.leading)
                .background(Color.clear)
                
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                
                interactionButtons
                    .padding(.trailing)
                    .background(Color.clear)
            }
            .padding(.bottom, bottomSafeAreaPadding + 10)
            .background(Color.clear)
        }
        .allowsHitTesting(true)
    }
    
    private var bottomSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
    }


    @ViewBuilder
    private var mediaContentLayer: some View {
        if isDummyItem {
            Image("pr0tok")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(50)
        } else if item.isVideo {
            if isActive && playerManager.showRetryButton && playerManager.playerItemID == item.id {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(playerManager.playerError ?? "Video konnte nicht geladen werden")
                        .foregroundColor(.white)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Erneut versuchen") {
                        playerManager.forceRetry()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if isActive, let player = playerManager.player, playerManager.playerItemID == item.id {
                 CustomVideoPlayerRepresentable(
                     player: player,
                     handler: keyboardActionHandlerForVideo,
                     onWillBeginFullScreen: onWillBeginFullScreenPr0Tok,
                     onWillEndFullScreen: onWillEndFullScreenPr0Tok,
                     horizontalSizeClass: nil
                 )
                 .id("video_\(item.id)")
             } else {
                 KFImage(item.thumbnailUrl)
                     .resizable()
                     .aspectRatio(contentMode: .fill)
                     .frame(maxWidth: .infinity, maxHeight: .infinity)
                     .clipped()
                     .overlay(ProgressView().scaleEffect(1.5).tint(.white).opacity(isActive && playerManager.playerItemID != item.id ? 1 : 0))
             }
        } else {
            KFImage(item.imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
        
    @ViewBuilder
    private var tagSection: some View {
        if isDummyItem {
            EmptyView()
        } else {
            switch itemData.itemInfoStatus {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
                    .background(Color.clear)
                    
            case .error(let msg):
                VStack(alignment: .leading) {
                    Text("Tags nicht geladen.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Erneut versuchen") {
                        onRetryLoadDetails()
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .background(Color.clear)
                }
                .background(Color.clear)
                
            case .loaded:
                if !itemData.displayedTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(itemData.displayedTags) { tag in
                            UnlimitedVotableTagView(
                                tag: tag,
                                currentVote: authService.votedTagStates[tag.id] ?? 0,
                                isVoting: authService.isVotingTag[tag.id] ?? false,
                                truncateText: true,
                                onUpvote: { onUpvoteTag(tag.id) },
                                onDownvote: { onDownvoteTag(tag.id) },
                                onTapTag: { onTagTapped(tag.tag) }
                            )
                        }
                        if itemData.totalTagCount > itemData.displayedTags.count {
                            let remainingCount = itemData.totalTagCount - itemData.displayedTags.count
                            Button {
                                onToggleShowAllTags()
                            } label: {
                                Text("+\(remainingCount) mehr")
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        } else if authService.isLoggedIn && itemData.totalTagCount == 0 {
                            Button {
                                onShowAddTagSheet()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.callout)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .background(Color.clear)
                } else if itemData.totalTagCount > 0 {
                    Text("Keine Tags (Filter?).")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .background(Color.clear)
                } else if authService.isLoggedIn {
                     Button {
                        onShowAddTagSheet()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            default:
                Text("Lade Tags...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .background(Color.clear)
            }
        }
    }
    
    @ViewBuilder
    private var interactionButtons: some View {
        if isDummyItem {
            EmptyView()
        } else {
            VStack(spacing: 25) {
                if !(authService.isVoting[item.id] ?? false) {
                    Button(action: onUpvoteItem) {
                        Image(systemName: itemData.currentVote == 1 ? "plus.circle.fill" : "plus.circle")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(itemData.currentVote == 1 ? Color.white : Color.white,
                                             itemData.currentVote == 1 ? Color.green : Color.white.opacity(0.7))
                    }
                    .disabled(!authService.isLoggedIn || (authService.isVoting[item.id] ?? false))
                } else {
                    ProgressView().tint(.white).scaleEffect(1.2)
                        .frame(width: 28, height: 28)
                }

                Text("\(item.up - item.down)")
                    .font(.callout.weight(.medium))
                    .foregroundColor(.white)
                    .shadow(radius: 1)

                if !(authService.isVoting[item.id] ?? false) {
                    Button(action: onDownvoteItem) {
                        Image(systemName: itemData.currentVote == -1 ? "minus.circle.fill" : "minus.circle")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(itemData.currentVote == -1 ? Color.white : Color.white,
                                             itemData.currentVote == -1 ? Color.red : Color.white.opacity(0.7))
                    }
                    .disabled(!authService.isLoggedIn || (authService.isVoting[item.id] ?? false))
                } else {
                    Spacer().frame(width: 28, height: 28)
                }

                Button {
                    onToggleFavorite()
                } label: {
                    if isProcessingFavorite {
                        ProgressView().tint(.white).scaleEffect(1.2)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: itemData.isFavorited ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(itemData.isFavorited ? .pink : .white)
                    }
                }
                .disabled(isProcessingFavorite || !authService.isLoggedIn)
                .highPriorityGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            Self.logger.debug("Long press detected on heart button for item \(item.id). Calling onShowCollectionSelection.")
                            if authService.isLoggedIn && !isProcessingFavorite {
                                Self.logger.debug("Conditions met (isLoggedIn: \(authService.isLoggedIn), !isProcessingFavorite: \(!isProcessingFavorite)), actually calling onShowCollectionSelection.")
                                onShowCollectionSelection()
                            } else {
                                Self.logger.debug("Conditions for onShowCollectionSelection NOT met. isLoggedIn: \(authService.isLoggedIn), isProcessingFavorite: \(isProcessingFavorite)")
                            }
                        }
                )
                
                Button {
                    Self.logger.info("Kommentar-Button getippt für Item \(item.id)")
                    onWillPresentCommentSheet()
                    showingCommentsSheet = true
                } label: {
                    Image(systemName: "message").font(.title).foregroundColor(.white)
                }

                Button {
                    onShareTapped()
                } label: {
                    Image(systemName: "arrowshape.turn.up.right").font(.title).foregroundColor(.white)
                }
            }
            .background(Color.clear)
        }
    }
}

#Preview {
    let settings = AppSettings()
    let authService = AuthService(appSettings: settings)
    let navService = NavigationService()
    settings.enableUnlimitedStyleFeed = true
    
    let dummyItem = Item(id: 1, promoted: nil, userId: 1, down: 10, up: 100, created: 0, image: "dummy.jpg", thumb: "dummy_thumb.jpg", fullsize: nil, preview: nil, width: 100, height: 100, audio: false, source: nil, flags: 1, user: "User", mark: 1, repost: false, variants: nil, subtitles: [ItemSubtitle(language: "de", path: "/some/path.vtt", label: "Deutsch", isDefault: true)])
    let sampleItemData = UnlimitedFeedItemDataModel(
        item: dummyItem,
        displayedTags: [ItemTag(id: 1, confidence: 1, tag: "Tag1")],
        totalTagCount: 1,
        comments: [],
        itemInfoStatus: .loaded,
        isFavorited: false,
        currentVote: 0
    )
    
    let dummyKeyboardHandler = KeyboardActionHandler()
    let previewPlayerManager = VideoPlayerManager()
    previewPlayerManager.configure(settings: settings)

    return UnlimitedFeedItemView(
        itemData: sampleItemData,
        playerManager: previewPlayerManager,
        keyboardActionHandlerForVideo: dummyKeyboardHandler,
        isActive: true,
        isDummyItem: false,
        onToggleShowAllTags: {},
        onUpvoteTag: { _ in },
        onDownvoteTag: { _ in },
        onTagTapped: { _ in },
        onRetryLoadDetails: {},
        onShowAddTagSheet: {},
        onShowFullscreenImage: { _ in },
        onToggleFavorite: {},
        onShowCollectionSelection: {},
        onShareTapped: {},
        isProcessingFavorite: false,
        onShowUserProfile: { username in print("Preview: Show profile for \(username)")},
        onWillBeginFullScreenPr0Tok: { print("Preview: Will begin fullscreen") },
        onWillEndFullScreenPr0Tok: { print("Preview: Will end fullscreen") },
        onUpvoteItem: { print("Preview: Upvote Item") },
        onDownvoteItem: { print("Preview: Downvote Item") },
        onWillPresentCommentSheet: { print("Preview: Will present comment sheet") },
        onDidDismissCommentSheet: { print("Preview: Did dismiss comment sheet") }
    )
    .environmentObject(settings)
    .environmentObject(authService)
    .environmentObject(navService)
}
// --- END OF COMPLETE FILE ---
