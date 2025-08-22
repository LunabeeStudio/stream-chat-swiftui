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
///   - Remove default padding
///   - Add topPadding (replace previous spacing from text)
///   - No longer handles quotedMessage, text and message modifier. Handled by the parent MessageView
public struct LinkAttachmentContainer<Factory: ViewFactory>: View {
    @Injected(\.colors) private var colors

    var factory: Factory
    var message: ChatMessage
    var width: CGFloat
    var isFirst: Bool
    @Binding var scrolledId: String?

    private let topPadding: CGFloat = 8

    public init(
        factory: Factory,
        message: ChatMessage,
        width: CGFloat,
        isFirst: Bool,
        scrolledId: Binding<String?>
    ) {
        self.factory = factory
        self.message = message
        self.width = width
        self.isFirst = isFirst
        _scrolledId = scrolledId
    }

    public var body: some View {
        VStack(
            alignment: message.alignmentInBubble,
            spacing: 8
        ) {
            if !message.linkAttachments.isEmpty {
                LinkAttachmentView(
                    linkAttachment: message.linkAttachments[0],
                    width: width,
                    isFirst: isFirst
                )
                .padding(.top, topPadding)
            }
        }
        .accessibilityIdentifier("LinkAttachmentContainer")
    }
}

/// View for previewing link attachments.
/// - Note: Changes from original implementation:
///   - Change VStack spacing
///   - Change LazyImage placeholder, width and radius
///   - Remove linkAttachment title and text
public struct LinkAttachmentView: View {
    @Injected(\.colors) private var colors
    @Injected(\.fonts) private var fonts

    var linkAttachment: ChatMessageLinkAttachment
    var width: CGFloat
    var isFirst: Bool
    
    public init(
        linkAttachment: ChatMessageLinkAttachment,
        width: CGFloat,
        isFirst: Bool
    ) {
        self.linkAttachment = linkAttachment
        self.width = width
        self.isFirst = isFirst
    }

    public var body: some View {
        Group {
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
                    .frame(width: width, height: (width / 2).rounded())
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
