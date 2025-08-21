//
// Copyright © 2025 Stream.io Inc. All rights reserved.
//

import StreamChat
import SwiftUI

/// Container for presenting link attachments.
/// In case of more than one link, only the first link is previewed.
/// - Note: Changes from original implementation:
///   - Change VStack spacing
///   - Remove bottom padding
///   - Add horizontal/vertical padding parameters
public struct LinkAttachmentContainer<Factory: ViewFactory>: View {
    @Injected(\.colors) private var colors

    var factory: Factory
    var message: ChatMessage
    var width: CGFloat
    var isFirst: Bool
    @Binding var scrolledId: String?

    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    
    public init(
        factory: Factory,
        message: ChatMessage,
        width: CGFloat,
        isFirst: Bool,
        scrolledId: Binding<String?>,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8
    ) {
        self.factory = factory
        self.message = message
        self.width = width
        self.isFirst = isFirst
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        _scrolledId = scrolledId
    }

    public var body: some View {
        VStack(
            alignment: message.alignmentInBubble,
            spacing: 8
        ) {
            if let quotedMessage = message.quotedMessage {
                factory.makeQuotedMessageView(
                    quotedMessage: quotedMessage,
                    fillAvailableSpace: !message.attachmentCounts.isEmpty,
                    isInComposer: false,
                    scrolledId: $scrolledId
                )
            }
            
            HStack {
                StreamTextView(message: message)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, verticalPadding)
                Spacer()
            }

            if !message.linkAttachments.isEmpty {
                LinkAttachmentView(
                    linkAttachment: message.linkAttachments[0],
                    width: width,
                    isFirst: isFirst,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding
                )
            }
        }
        .modifier(
            factory.makeMessageViewModifier(
                for: MessageModifierInfo(
                    message: message,
                    isFirst: isFirst,
                    injectedBackgroundColor: colors.highlightedAccentBackground1
                )
            )
        )
        .accessibilityIdentifier("LinkAttachmentContainer")
    }
}

/// View for previewing link attachments.
/// - Note: Changes from original implementation:
///   - Change VStack spacing
///   - Change LazyImage placeholder, width and radius
///   - Remove linkAttachment title and text
///   - Add horizontal/vertical padding parameters
public struct LinkAttachmentView: View {
    @Injected(\.colors) private var colors
    @Injected(\.fonts) private var fonts

    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat

    var linkAttachment: ChatMessageLinkAttachment
    var width: CGFloat
    var isFirst: Bool
    
    public init(
        linkAttachment: ChatMessageLinkAttachment,
        width: CGFloat,
        isFirst: Bool,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) {
        self.linkAttachment = linkAttachment
        self.width = width
        self.isFirst = isFirst
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !imageHidden {
                ZStack {
                    LazyImage(url: linkAttachment.previewURL ?? linkAttachment.originalURL) { state in
                        if let image = state.image {
                            image
                                .scaledToFill()
                        } else {
                            Color.gray
                        }
                    }
                    .onDisappear(.cancel)
                    .processors([ImageProcessors.Resize(width: width)])
                    .priority(.high)
                    .frame(width: width - 2 * horizontalPadding, height: ((width - 2 * horizontalPadding) / 2).rounded())
                    .cornerRadius(12)

                    if !authorHidden {
                        BottomLeftView {
                            Text(linkAttachment.author ?? "")
                                .foregroundColor(colors.tintColor)
                                .font(fonts.bodyBold)
                                .standardPadding()
                                .bubble(
                                    with: Color(colors.highlightedAccentBackground1),
                                    corners: [.topRight],
                                    borderColor: .clear
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, verticalPadding)
        .onTapGesture {
            if let url = linkAttachment.originalURL.secureURL, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        }
        .accessibilityIdentifier("LinkAttachmentView")
    }

    private var imageHidden: Bool {
        linkAttachment.previewURL == nil
    }

    private var authorHidden: Bool {
        linkAttachment.author == nil
    }
}
