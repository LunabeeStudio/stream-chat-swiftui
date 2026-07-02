//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import StreamChat
import SwiftUI

public struct MessageView<Factory: ViewFactory>: View {
    @Injected(\.utils) private var utils

    private var messageTypeResolver: MessageTypeResolving {
        utils.messageTypeResolver
    }

    public var factory: Factory
    public var message: ChatMessage
    public var contentWidth: CGFloat
    public var isFirst: Bool
    public var showBubble: Bool
    public var translationLanguage: TranslationLanguage?
    @Binding public var scrolledId: String?

    private let availableWidth: CGFloat
    public let bubbleHorizontalPadding: CGFloat = 12
    public let bubbleVerticalPadding: CGFloat = 8

    public init(
        factory: Factory,
        message: ChatMessage,
        contentWidth: CGFloat,
        isFirst: Bool,
        showBubble: Bool = true,
        scrolledId: Binding<String?>,
        translationLanguage: TranslationLanguage? = nil
    ) {
        self.factory = factory
        self.message = message
        self.contentWidth = contentWidth
        self.isFirst = isFirst
        self.showBubble = showBubble
        self.translationLanguage = translationLanguage
        availableWidth = showBubble ? contentWidth - (2 * bubbleHorizontalPadding) : contentWidth
        _scrolledId = scrolledId
    }

    // - Note: Fork composition layout. Instead of picking a single view to render the whole
    //   message, `MessageView` composes a stack of every required piece in a fixed order, so a
    //   message can show multiple attachment types at once (e.g. image + file, or several custom
    //   attachment views). Custom attachments have two possible positions (`.top` / `.bottom`).
    //   This view owns the quotedMessage view, the text and the message bubble modifier — the
    //   subviews no longer handle them. `showBubble` controls the bubble background, the content
    //   padding and the available width.
    public var body: some View {
        if messageTypeResolver.isDeleted(message: message) {
            factory.makeDeletedMessageView(
                options: DeletedMessageViewOptions(
                    message: message,
                    isFirst: isFirst,
                    availableWidth: availableWidth
                )
            )
        } else {
            messageContent
                .padding(.horizontal, showBubble ? bubbleHorizontalPadding : 0)
                .padding(.vertical, showBubble ? bubbleVerticalPadding : 0)
                .modifier(
                    factory.styles.makeMessageViewModifier(
                        for: MessageModifierInfo(
                            message: message,
                            isFirst: isFirst,
                            showBubble: showBubble
                        )
                    )
                )
        }
    }

    private var messageContent: some View {
        VStack(alignment: message.alignmentInBubble, spacing: 0) {
            if let quotedMessage = message.quotedMessage {
                factory.makeChatQuotedMessageView(
                    options: ChatQuotedMessageViewOptions(
                        quotedMessage: quotedMessage,
                        parentMessage: message,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasCustomAttachment(message: message, layout: .top) {
                factory.makeCustomAttachmentViewType(
                    options: CustomAttachmentViewTypeOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId,
                        layout: .top
                    )
                )
            }

            if messageTypeResolver.hasImageAttachment(message: message) {
                factory.makeImageAttachmentView(
                    options: ImageAttachmentViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if message.shouldRenderAsJumbomoji {
                factory.makeEmojiTextView(
                    options: EmojiTextViewOptions(
                        message: message,
                        scrolledId: $scrolledId,
                        isFirst: isFirst
                    )
                )
            } else if !message.text.isEmpty {
                factory.makeMessageTextView(
                    options: MessageTextViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId,
                        translationLanguage: translationLanguage
                    )
                )
            }

            if messageTypeResolver.hasGiphyAttachment(message: message) {
                factory.makeGiphyAttachmentView(
                    options: GiphyAttachmentViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasVideoAttachment(message: message)
                && !messageTypeResolver.hasImageAttachment(message: message) {
                factory.makeVideoAttachmentView(
                    options: VideoAttachmentViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasVoiceRecording(message: message) {
                factory.makeVoiceRecordingView(
                    options: VoiceRecordingViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasLinkAttachment(message: message)
                && message.attachmentCounts.keys.allSatisfy({ $0 == .linkPreview }) {
                factory.makeLinkAttachmentView(
                    options: LinkAttachmentViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasFileAttachment(message: message) {
                factory.makeFileAttachmentView(
                    options: FileAttachmentViewOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId
                    )
                )
            }

            if messageTypeResolver.hasCustomAttachment(message: message, layout: .bottom) {
                factory.makeCustomAttachmentViewType(
                    options: CustomAttachmentViewTypeOptions(
                        message: message,
                        isFirst: isFirst,
                        availableWidth: availableWidth,
                        scrolledId: $scrolledId,
                        layout: .bottom
                    )
                )
            }

            if let poll = message.poll {
                factory.makePollView(
                    options: PollViewOptions(
                        message: message,
                        poll: poll,
                        isFirst: isFirst,
                        availableWidth: availableWidth
                    )
                )
            }
        }
    }
}

public struct MessageTextView<Factory: ViewFactory>: View {
    @Injected(\.colors) private var colors
    @Injected(\.fonts) private var fonts
    @Injected(\.utils) private var utils

    private let factory: Factory
    private let message: ChatMessage
    private let isFirst: Bool
    private let translationLanguage: TranslationLanguage?
    private let leadingPadding: CGFloat
    private let trailingPadding: CGFloat
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat
    @Binding var scrolledId: String?

    public init(
        factory: Factory,
        message: ChatMessage,
        isFirst: Bool,
        scrolledId: Binding<String?>,
        translationLanguage: TranslationLanguage?
    ) {
        // - Note: Fork composition — paddings default to 0 because the parent `MessageView`
        //   owns the bubble padding around the whole composed message content.
        self.init(
            factory: factory,
            message: message,
            isFirst: isFirst,
            leadingPadding: 0,
            trailingPadding: 0,
            topPadding: 0,
            bottomPadding: 0,
            scrolledId: scrolledId,
            translationLanguage: translationLanguage
        )
    }

    public init(
        factory: Factory,
        message: ChatMessage,
        isFirst: Bool,
        leadingPadding: CGFloat,
        trailingPadding: CGFloat,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        scrolledId: Binding<String?>,
        translationLanguage: TranslationLanguage?
    ) {
        self.factory = factory
        self.message = message
        self.isFirst = isFirst
        self.translationLanguage = translationLanguage
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        _scrolledId = scrolledId
    }

    // - Note: Fork composition — no longer handles quotedMessage or the message bubble modifier.
    //   Those are owned by the parent `MessageView`.
    public var body: some View {
        factory.makeStreamTextView(options: .init(
            message: message,
            translationLanguage: translationLanguage
        ))
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("MessageTextView")
    }
}

public struct EmojiTextView<Factory: ViewFactory>: View {
    var factory: Factory
    var message: ChatMessage
    @Binding var scrolledId: String?
    var isFirst: Bool

    @Injected(\.fonts) private var fonts

    // - Note: Fork composition — no longer handles quotedMessage or the message bubble modifier.
    //   Those are owned by the parent `MessageView`.
    public var body: some View {
        Text(message.adjustedText)
            .font(fonts.emoji)
            .accessibilityIdentifier("MessageTextView")
    }
}

struct StreamTextView: View {
    @Environment(\.layoutDirection) var layoutDirection
    @Injected(\.colors) var colors
    @Injected(\.fonts) var fonts

    let message: ChatMessage
    let textContent: String
    let translationLanguage: TranslationLanguage?

    init(message: ChatMessage, translationLanguage: TranslationLanguage?) {
        self.message = message
        self.textContent = message.textContent(for: translationLanguage) ?? message.adjustedText
        self.translationLanguage = translationLanguage
    }

    var body: some View {
        if #available(iOS 15, *) {
            let attributedText = message.attributedTextContent(
                layoutDirection: layoutDirection,
                translationLanguage: translationLanguage
            )
            Text(attributedText)
                .foregroundColor(textColor(for: message))
                .font(fonts.body)
                .tint(Color(colors.accentPrimary))
        } else {
            Text(textContent)
                .foregroundColor(textColor(for: message))
                .font(fonts.body)
        }
    }
}
