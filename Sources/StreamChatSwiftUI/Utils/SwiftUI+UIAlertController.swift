//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

extension View {
    /// Presents an alert with a text field for entering text.
    func uiAlert(
        title: String,
        isPresented: Binding<Bool>,
        message: String = "",
        text: Binding<String>,
        placeholder: String = "",
        validation: @escaping (String) -> Bool = { !$0.trimmed.isEmpty },
        cancel: String = L10n.Alert.Actions.cancel,
        accept: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            TextFieldAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                text: text,
                placeholder: placeholder,
                validation: validation,
                cancel: cancel,
                accept: accept,
                action: action
            )
        )
    }
}

// `UIAlertController` misplaces its text field on some devices (e.g. iPhone Duo), so the
// SwiftUI alert is used.
private struct TextFieldAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    @Binding var text: String
    let placeholder: String
    let validation: (String) -> Bool
    let cancel: String
    let accept: String
    let action: () -> Void

    @State private var draft = ""

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField(placeholder, text: $draft)
                Button(cancel, role: .cancel) {}
                Button(accept) {
                    text = draft.trimmed
                    action()
                }
                .disabled(!validation(draft))
            } message: {
                if !message.isEmpty {
                    Text(message)
                }
            }
            .onChange(of: isPresented) { presented in
                if presented {
                    draft = text
                }
            }
    }
}
