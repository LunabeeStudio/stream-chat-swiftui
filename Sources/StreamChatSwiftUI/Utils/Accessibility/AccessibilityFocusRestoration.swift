//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Returns VoiceOver focus to this view when the presentation binding
    /// flips from `true` to `false`.
    ///
    /// Native modal/sheet dismissal sometimes leaves VoiceOver focus orphaned
    /// on a stale element (commonly the back button or the channel header)
    /// instead of returning it to the originating element. This modifier
    /// keeps a small delay so the dismissal animation can settle before
    /// VoiceOver moves focus.
    ///
    /// Uses `@AccessibilityFocusState`.
    func restoresAccessibilityFocusOnDismiss(of isPresented: Binding<Bool>) -> some View {
        modifier(RestoresAccessibilityFocusOnDismissModifier(isPresented: isPresented))
    }
}

private struct RestoresAccessibilityFocusOnDismissModifier: ViewModifier {
    @Binding var isPresented: Bool
    @AccessibilityFocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: isPresented) { isShown in
                guard !isShown else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            }
    }
}
