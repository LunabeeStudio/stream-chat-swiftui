//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import StreamChat
import SwiftUI

/// View for the chat channel.
public struct ChatChannelView<Factory: ViewFactory>: View, KeyboardReadable {
    @Injected(\.colors) private var colors
    @Injected(\.utils) private var utils
    @Injected(\.chatClient) private var chatClient

    @StateObject private var viewModel: ChatChannelViewModel

    @Environment(\.presentationMode) var presentationMode

    @State private var messageDisplayInfo: MessageDisplayInfo?
    @State private var keyboardShown = false
    @State private var tabBarAvailable: Bool = false
    @State private var floatingComposerHeight: CGFloat
    
    private var factory: Factory

    public init(
        viewFactory: Factory = DefaultViewFactory.shared,
        viewModel: ChatChannelViewModel? = nil,
        channelController: ChatChannelController,
        messageController: ChatMessageController? = nil,
        scrollToMessage: ChatMessage? = nil,
        composerPlacement: ComposerPlacement = .floating
    ) {
        _floatingComposerHeight = State(initialValue: Self.defaultFloatingComposerHeight())
        _viewModel = StateObject(
            wrappedValue: viewModel ?? ViewModelsFactory.makeChannelViewModel(
                with: channelController,
                messageController: messageController,
                scrollToMessage: scrollToMessage
            )
        )
        factory = viewFactory
    }

    public var body: some View {
        ZStack {
            if let channel = viewModel.channel {
                VStack(spacing: 0) {
                    if !viewModel.messages.isEmpty {
                        MessageListView(
                            factory: factory,
                            channel: channel,
                            messages: viewModel.messages,
                            messagesGroupingInfo: viewModel.messagesGroupingInfo,
                            scrolledId: $viewModel.scrolledId,
                            showScrollToLatestButton: $viewModel.showScrollToLatestButton,
                            quotedMessage: $viewModel.quotedMessage,
                            currentDateString: viewModel.currentDateString,
                            listId: viewModel.listId,
                            isMessageThread: viewModel.isMessageThread,
                            shouldShowTypingIndicator: viewModel.shouldShowInlineTypingIndicator,
                            bottomInset: composerPlacement == .floating ? floatingComposerHeight - (keyboardShown ? bottomPadding : 0) : 0,
                            scrollPosition: $viewModel.scrollPosition,
                            loadingNextMessages: viewModel.loadingNextMessages,
                            firstUnreadMessageId: $viewModel.firstUnreadMessageId,
                            onMessageAppear: viewModel.handleMessageAppear(index:scrollDirection:),
                            onScrollToBottom: viewModel.scrollToLastMessage,
                            onLongPress: { displayInfo in
                                let isBouncedAlertEnabled = utils.messageListConfig.bouncedMessagesAlertActionsEnabled
                                if isBouncedAlertEnabled && displayInfo.message.isBounced {
                                    viewModel.showBouncedActionsView(for: displayInfo.message)
                                } else if displayInfo.showsMessageActions {
                                    messageDisplayInfo = displayInfo
                                    withAnimation {
                                        viewModel.showReactionOverlay(for: AnyView(self))
                                    }
                                } else {
                                    viewModel.reactionsDetailMessage = displayInfo.message
                                }
                            },
                            onJumpToMessage: viewModel.jumpToMessage(messageId:)
                        )
                        .edgesIgnoringSafeArea(.bottom)
                        .environment(\.highlightedMessageId, viewModel.highlightedMessageId)
                        .dismissKeyboardOnTap(enabled: true) {
                            hideComposerCommandsAndAttachmentsPicker()
                        }
                        .overlay(
                            viewModel.currentDateString != nil ?
                                VStack {
                                    factory.makeDateIndicatorView(options: DateIndicatorViewOptions(dateString: viewModel.currentDateString!))
                                    Spacer()
                                }
                                : nil
                        )
                    } else {
                        ZStack {
                            factory.makeEmptyMessagesView(options: EmptyMessagesViewOptions(channel: channel))
                                .dismissKeyboardOnTap(enabled: keyboardShown) {
                                    hideComposerCommandsAndAttachmentsPicker()
                                }
                            if viewModel.shouldShowInlineTypingIndicator {
                                factory.makeInlineTypingIndicatorView(
                                    options: TypingIndicatorViewOptions(
                                        channel: channel,
                                        currentUserId: chatClient.currentUserId
                                    )
                                )
                            }
                        }
                    }

                    Divider()
                        .opacity(0)
                        .navigationBarBackButtonHidden(viewModel.reactionsShown)
                        .if(viewModel.reactionsShown, transform: { view in
                            view.modifier(factory.makeChannelBarsVisibilityViewModifier(options: ChannelBarsVisibilityViewModifierOptions(shouldShow: false)))
                        })
                        .if(!viewModel.reactionsShown, transform: { view in
                            view.modifier(factory.makeChannelBarsVisibilityViewModifier(options: ChannelBarsVisibilityViewModifierOptions(shouldShow: true)))
                        })
                        .if(viewModel.channelHeaderType != .messageThread) { view in
                            view.modifier(factory.makeChannelHeaderViewModifier(
                                options: ChannelHeaderViewModifierOptions(
                                    channel: channel,
                                    shouldShowTypingIndicator: viewModel.shouldShowNavigationBarTypingIndicator
                                )
                            ))
                        }
                        .if(viewModel.channelHeaderType == .messageThread) { view in
                            view.modifier(factory.makeMessageThreadHeaderViewModifier(options: MessageThreadHeaderViewModifierOptions()))
                        }
                        .animation(nil)

                    if composerPlacement == .docked {
                        composerView
                            .opacity((
                                utils.messageListConfig.messagePopoverEnabled && messageDisplayInfo != nil && !viewModel
                                    .reactionsShown && viewModel.channel?.isFrozen == false
                            ) ? 0 : 1)
                            // Ensure a minimum gap on devices with no bottom safe area (e.g. iPhone SE);
                            // 0 on devices where the safe area already provides it.
                            .padding(.bottom, composerBottomInset - bottomPadding)
                    }

                    NavigationLink(
                        isActive: $viewModel.threadMessageShown
                    ) {
                        if let message = viewModel.threadMessage {
                            let threadDestination = factory.makeMessageThreadDestination(options: MessageThreadDestinationOptions())
                            threadDestination(channel, message)
                        } else {
                            EmptyView()
                        }
                    } label: {
                        EmptyView()
                    }
                    .opacity(0) // Fixes showing accessibility button shape
                }
                // While the reactions overlay is shown it acts as a modal: hide the
                // chat content behind it so VoiceOver only exposes the overlay's
                // reactions and message actions. Applied before `.overlay` so the
                // overlay itself stays accessible.
                .accessibilityHidden(viewModel.reactionsShown)
                .overlay(
                    viewModel.currentSnapshot != nil && messageDisplayInfo != nil && viewModel.reactionsShown ?
                        factory.makeReactionsOverlayView(
                            options: ReactionsOverlayViewOptions(
                                channel: channel,
                                currentSnapshot: viewModel.currentSnapshot!,
                                messageDisplayInfo: messageDisplayInfo!,
                                onBackgroundTap: {
                                    viewModel.reactionsShown = false
                                    if messageDisplayInfo?.keyboardWasShown == true {
                                        becomeFirstResponder()
                                    }
                                    messageDisplayInfo = nil
                                }, onActionExecuted: { actionInfo in
                                    viewModel.messageActionExecuted(actionInfo)
                                    messageDisplayInfo = nil
                                }
                            )
                        )
                        .transition(.identity)
                        .edgesIgnoringSafeArea(.all)
                        : nil
                )
                .modifier(FloatingComposerContainer(
                    composerPlacement: composerPlacement,
                    composer: {
                        composerView
                            .padding(.bottom, floatingComposerBottomPadding)
                            .opacity(viewModel.reactionsShown ? 0 : 1)
                            .accessibilityHidden(viewModel.reactionsShown)
                    }
                ))
            } else {
                factory.makeChannelLoadingView(options: ChannelLoadingViewOptions())
            }
        }
        .onPreferenceChange(FloatingComposerHeightPreferenceKey.self) { value in
            guard composerPlacement == .floating, value > 0 else { return }
            // Reserve `composerBottomInset` (not raw safe area) so the last message clears the composer
            // even on devices with no bottom safe area.
            floatingComposerHeight = value + composerBottomInset
        }
        .navigationBarTitleDisplayMode(utils.messageListConfig.navigationBarDisplayMode)
        .onReceive(keyboardWillChangePublisher, perform: { visible in
            keyboardShown = visible
        })
        .onReceive(NotificationCenter.default.publisher(
            for: NSNotification.Name(dismissChannel)
        ), perform: { _ in
            presentationMode.wrappedValue.dismiss()
        })
        .onAppear {
            viewModel.onViewAppear()
            if utils.messageListConfig.becomesFirstResponderOnOpen {
                keyboardShown = true
            }
        }
        .onDisappear {
            viewModel.onViewDissappear()
            viewModel.reactionsShown = false
            messageDisplayInfo = nil
        }
        .background(
            Color(factory.styles.composerPlacement == .docked ? colors.backgroundCoreElevation1 : .clear)
                .background(
                    TabBarAccessor { _ in
                        tabBarAvailable = utils.messageListConfig.handleTabBarVisibility
                    }
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        )
        .padding(.bottom, contentBottomPadding)
        // Fork: also ignore the bottom safe area for a floating composer (not just when a tab bar is
        // present), so the message list scrolls under the floating composer into the bottom safe area.
        // The composer is kept above the safe area via `floatingComposerBottomPadding`.
        .ignoresSafeArea(.container, edges: (tabBarAvailable || composerPlacement == .floating) ? .bottom : [])
        .alertBanner(isPresented: $viewModel.showAlertBanner)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ChatChannelView")
        .modifier(factory.styles.makeBouncedMessageActionsModifier(viewModel: viewModel))
        .accentColor(Color(colors.accentPrimary))
        .sheet(item: $viewModel.reactionsDetailMessage) { message in
            factory.makeReactionsDetailView(
                options: ReactionsDetailViewOptions(message: message)
            )
            .modifier(PresentationDetentsModifier(sheetSizes: [.medium, .large]))
        }
    }
    
    private var composerView: some View {
        factory.makeMessageComposerViewType(
            options: MessageComposerViewTypeOptions(
                channelController: viewModel.channelController,
                messageController: viewModel.messageController,
                quotedMessage: $viewModel.quotedMessage,
                editedMessage: $viewModel.editedMessage,
                willSendMessage: {
                    viewModel.messageSentTapped()
                }
            )
        )
    }
    
    private var composerPlacement: ComposerPlacement {
        factory.styles.composerPlacement
    }

    private var generatingSnapshot: Bool {
        if #available(iOS 26, *) {
            false
        } else {
            tabBarAvailable && messageDisplayInfo != nil && !viewModel.reactionsShown
        }
    }

    private var bottomPadding: CGFloat {
        topVC()?.view.safeAreaInsets.bottom ?? 0
    }

    /// Minimum gap below the composer, so it isn't flush on devices with **no bottom safe area**
    /// (e.g. iPhone SE / Touch-ID iPhones).
    private let minComposerBottomInset: CGFloat = 8

    /// The composer's effective bottom inset: the bottom safe area, or `minComposerBottomInset` when the
    /// device has no safe area. Used by both the docked and floating composer so neither sits flush.
    private var composerBottomInset: CGFloat {
        max(bottomPadding, minComposerBottomInset)
    }

    /// Whether the main **content** needs manual bottom safe-area compensation.
    ///
    /// Drives `contentBottomPadding` only, and is intentionally **tab-bar-only**. A floating composer
    /// must NOT be included here: in that case the content ignores the bottom safe area (so it can
    /// scroll under the composer) and the composer owns the padding instead (`floatingComposerBottomPadding`).
    /// Adding `.floating` here double-pads — the content shifts up **and** the composer pads — which
    /// breaks the floating layout.
    private var needsBottomSafeAreaPadding: Bool {
        !keyboardShown && tabBarAvailable
    }

    /// Whether the floating composer should own the bottom safe-area padding
    /// instead of the main content. This happens in threads and during
    /// pre-iOS 26 snapshot generation, where the content skips its own padding.
    private var floatingComposerOwnsBottomPadding: Bool {
        composerPlacement == .floating && (viewModel.isMessageThread || generatingSnapshot)
    }

    /// Bottom padding for the main content area.
    private var contentBottomPadding: CGFloat {
        guard needsBottomSafeAreaPadding, !generatingSnapshot else { return 0 }
        return floatingComposerOwnsBottomPadding ? 0 : bottomPadding
    }

    /// Bottom padding for the floating composer overlay.
    ///
    /// Uses its **own** condition (not `needsBottomSafeAreaPadding`, which is content/tab-bar only) so
    /// exactly one of {content, composer} owns the bottom safe area per case:
    /// - thread / snapshot → composer owns it (the content skips its own padding).
    /// - no tab bar → the content ignores the bottom safe area and scrolls under, so the composer must
    ///   sit above it — matching the `+ composerBottomInset` reserved in `floatingComposerHeight`.
    /// - tab bar → `0`; the content owns it via `contentBottomPadding`.
    /// - keyboard shown → `0`; the keyboard already provides the inset (and `bottomInset` subtracts it).
    private var floatingComposerBottomPadding: CGFloat {
        guard composerPlacement == .floating, !keyboardShown else { return 0 }
        if floatingComposerOwnsBottomPadding { return composerBottomInset } // thread/snapshot
        return tabBarAvailable ? 0 : composerBottomInset // no tab bar → composer owns it
    }

    private func hideComposerCommandsAndAttachmentsPicker() {
        NotificationCenter.default.post(
            name: .attachmentPickerHiddenNotification, object: nil
        )
        NotificationCenter.default.post(
            name: .commandsOverlayHiddenNotification, object: nil
        )
    }
}

public enum ComposerPlacement {
    case docked
    case floating
}

private extension ChatChannelView {
    static func defaultFloatingComposerHeight() -> CGFloat {
        let utils = InjectedValues[\.utils]
        let baseHeight = utils.composerConfig.inputViewMinHeight
        let spacing: CGFloat = 60
        return baseHeight + spacing
    }
}

private struct FloatingComposerContainer<Composer: View>: ViewModifier {
    let composerPlacement: ComposerPlacement
    let composer: () -> Composer

    func body(content: Content) -> some View {
        if composerPlacement == .docked {
            content
        } else {
            if #available(iOS 15.0, *) {
                content
                    .overlay(alignment: .bottom) {
                        composer()
                    }
            } else {
                content
                    .overlay(
                        VStack {
                            Spacer()
                            composer()
                        }
                    )
            }
        }
    }
}
