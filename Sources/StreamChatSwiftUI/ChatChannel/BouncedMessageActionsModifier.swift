//
// Copyright © 2025 Stream.io Inc. All rights reserved.
//

import StreamChat
import SwiftUI

/// The modifier that shows the actions for a bounced message.
///
/// This modifier is only used if `Utils.messageListConfig.bouncedMessagesAlertActionsEnabled` is `true`.
public struct BouncedMessageActionsModifier: ViewModifier {
    @ObservedObject private var viewModel: ChatChannelViewModel

    public init(
        viewModel: ChatChannelViewModel
    ) {
        self.viewModel = viewModel
    }

    public func body(content: Content) -> some View {
        content
            .alert(
                L10n.Message.Moderation.Alert.title,
                isPresented: $viewModel.bouncedActionsViewShown
            ) {
                Button(L10n.Message.Moderation.Alert.resend) {
                    resendBouncedMessage()
                }
                Button(L10n.Message.Moderation.Alert.edit) {
                    editBouncedMessage()
                }
                Button(L10n.Message.Moderation.Alert.delete, role: .destructive) {
                    deleteBouncedMessage()
                }
                Button(L10n.Message.Moderation.Alert.cancel, role: .cancel, action: {
                    viewModel.bouncedActionsViewShown = false
                })
            } message: {
                Text(L10n.Message.Moderation.Alert.message)
            }
    }

    private func editBouncedMessage() {
        guard let bouncedMessage = viewModel.bouncedMessage else {
            return
        }
        viewModel.editMessage(bouncedMessage)
    }

    private func resendBouncedMessage() {
        guard let bouncedMessage = viewModel.bouncedMessage else {
            return
        }
        viewModel.resendMessage(bouncedMessage)
    }

    private func deleteBouncedMessage() {
        guard let bouncedMessage = viewModel.bouncedMessage else {
            return
        }
        viewModel.deleteMessage(bouncedMessage)
    }
}
