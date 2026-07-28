# Fork specificities — StreamChatSwiftUI (LunabeeStudio)

This fork tracks GetStream's `stream-chat-swiftui`. This document lists everything that differs
between this fork (`feature/v5-migration`) and the upstream release it is based on, **v5.5.1**
(git tag `5.5.1`). Use it when reconciling against future upstream bumps.

Scope of diff: `git diff 5.5.1..feature/v5-migration` — 19 SDK source files (+ demo + tests).
Every forked SDK file carries an inline `- Note:` comment describing its divergence; grep for
`Fork` / `Changes from original implementation` to find them.

---

## 1. Platform — minimum iOS 14 → 15

- `Package.swift`: `.iOS(.v14)` → `.iOS(.v15)`; Xcode deployment target `15.6` on the 3 SDK build configs.
- Removed all `if #available(iOS 15)` / `@available(iOS 15)` fallbacks:
  `BouncedMessageActionsModifier` (drops the iOS-14 `actionSheet` branch, keeps `.alert`),
  `ChatChannelListView` (`setupTabBarAppeareance`), `ChatChannelListViewModel` (`checkTabBarAppearance`),
  `AlertBannerViewModifier`, `AttributedString+Extensions`, `MarkdownFormatter`.

These should become no-op conflicts as upstream also requires iOS 15+.

## 2. Message rendering — composition layout (the core divergence)

`ChatMessageList/MessageView.swift`

- Upstream renders a message by picking **one** exclusive branch (`if / else if`). The fork
  **composes** a single `VStack` of every relevant piece, in a fixed order:
  `quoted → custom(.top) → image → emoji/text → giphy → video → voice → link → file → custom(.bottom) → poll`.
  A message can therefore show **multiple attachment types at once** (e.g. image + file, or several
  custom attachment views).
- `MessageView` **owns** the quoted-message view, the text, and the message bubble modifier +
  content padding. Its subviews no longer do.
- Added `showBubble: Bool = true`, `availableWidth` (= `contentWidth − 2·bubbleHorizontalPadding`
  when bubbled), `bubbleHorizontalPadding = 12`, `bubbleVerticalPadding = 8`.
- Subviews stripped to "dumb" (render only their own content, no quoted/text/bubble):
  `MessageTextView` (default paddings 0), `EmojiTextView`, `GiphyAttachmentView`,
  `PollAttachmentView`. (Upstream's image/file/video/voice/link views were already dumb.)

## 3. `showBubble` feature

Lets specific messages render without the bubble background **and** without the bubble's interior
padding (content sits flush).

- Threaded: `MessageItemView` → `MessageContainerView` → `MessageView` →
  `MessageBubbleModifier` (via `Styles.makeMessageViewModifier`, which now forwards `showBubble`).
- `MessageBubble.swift`: `MessageModifierInfo.showBubble` + `MessageBubbleModifier` `showBubble`
  gate (`if showBubble { bubble } else { content }`).
- The app sets `showBubble: false` per message via a custom `factory.makeMessageItemView(...)`.

## 4. Custom-attachment layout feature

Lets custom attachments render in **two independent slots** (before/after the rest of the content).

- `MessageTypeResolver.swift`: `public enum CustomAttachmentLayout { all, top, bottom }` +
  `hasCustomAttachment(message:layout:)` (upstream: `hasCustomAttachment(message:)`).
- `ViewFactory/Options/AttachmentViewFactoryOptions.swift`: `CustomAttachmentViewTypeOptions.layout`
  field (default `.all`).
- `MessageView` calls `hasCustomAttachment(..., layout: .top)` and `.bottom` around the other content.

## 5. Layout & padding

- `MessageItemView.swift`:
  - `extraTrailingPadding = 8` — subtracted from `contentWidth` and applied as `.padding(.trailing, 8)`
    on the message row (bubbles don't sit flush against the trailing edge).
  - `hasHorizontalSpacer: Bool = true` — when `false`, `spacerWidth` returns `0` so the message can
    use the full width. Set per message via a custom `makeMessageItemView`.
- `MessageContainerView.swift`: `extraBottomPadding = 8`; HStack spacing tweaks;
  `deliveryStatusView` phantom-padding fix (only pads the read-indicator/date `HStack` when the
  date is shown); the message-actions gesture (`MessageActionsGestureModifier` + `contentShape`)
  is applied on the **bubble content** here rather than on the whole row in `MessageItemView`,
  so it only triggers on the bubble.
- `ChatComposer/MessageComposerView.swift`: leading composer `HStack` alignment `.center`
  (upstream `.bottom`).
- **Grouped-message spacing**: upstream adds `messagePaddings.groupBottom` (default 4) between
  consecutive messages; the fork's v4 behaviour was `0`. This is **not** patched in the SDK —
  get parity app-side with `MessagePaddings(groupBottom: 0)` in `MessageListConfig`.
- `ChatChannel/ChatChannelView.swift` — **floating composer & bottom safe area**. Upstream only
  ignores the bottom safe area when a tab bar is present, so with a floating composer and **no** tab
  bar the message list stops above the safe area. Fork makes the list scroll **under** the floating
  composer into the bottom safe area while the composer stays **above** it:
  - `.ignoresSafeArea(.container, edges:)` ignores `.bottom` when `tabBarAvailable || composerPlacement == .floating` (was `tabBarAvailable` only); `MessageListView` also carries `.edgesIgnoringSafeArea(.bottom)`.
  - `needsBottomSafeAreaPadding` kept **tab-bar-only** (`!keyboardShown && tabBarAvailable`) — it drives `contentBottomPadding`; a floating composer must be excluded or the content double-pads (shifts up **and** the composer pads).
  - `floatingComposerBottomPadding` uses its **own** condition (`floating && !keyboardShown`): composer owns the safe-area padding when there's no tab bar, `0` with a tab bar (content owns it), `bottomPadding` for thread/snapshot — matching the `+ bottomPadding` reserved in `floatingComposerHeight`.
  - Invariant: exactly one of {content, composer} owns the bottom safe-area padding per case.
  - **Min composer bottom inset** — the composer must not sit flush against its bottom boundary, in two cases: (a) while the **keyboard is shown** (gap between composer and keyboard top), and (b) on devices with **no bottom safe area** (iPhone SE / Touch-ID) at the physical bottom. The gap is owned by the **composer content**, not the channel slot, so each composer decides independently:
    - `ChatChannelView` reserves only the raw bottom safe area (`bottomPadding`). The docked branch adds no padding; the floating path uses `bottomPadding` for both `floatingComposerBottomPadding` and the `floatingComposerHeight` reserve. (Earlier fork revisions had a `composerBottomInset = max(bottomPadding, 8)` helper applied at the slot for **both** composer states — removed, since it forced the gap on every composer.)
    - `ChatComposer/MessageComposerView.swift` adds its own `minBottomInset` (`keyboardShown || bottomSafeArea == 0 ? 8 : 0`) as the outermost `.padding(.bottom, …)`. So the interactive composer keeps an 8pt gap above the keyboard and on SE, while a flush composer (e.g. the app's locked-chat composer returned from `makeMessageComposerViewType`) simply omits it and sits flush.
    - On a home-indicator device with the keyboard **down** this is a no-op (safe area handles it). The keyboard-up gap is not a v4 regression per se, but v5's floating-composer path dropped it (both `floatingComposerBottomPadding` and `minBottomInset` collapsed to 0 while the keyboard was shown) — this restores it.

## 6. Reactions overlay

`ChatMessageList/Reactions/ReactionsOverlayContainer.swift`

- Made `public`; added `customHorizontalOffset: CGFloat?` and a manual
  `.offset(x: messageOffsetX, y: -20)` (upstream positions the overlay itself and has no offset).
  The app passes a negative `customHorizontalOffset` to nudge reactions on some messages.
- Re-added `ChatMessage.reactionOffsetX(for:availableWidth:reactionsSize:)` (fork helper, `@MainActor`).
- ⚠️ Verify visually against upstream's overlay layout on each bump.

## 7. Bubble styling — aligned to v5 (documented only)

`MessageBubble.swift` keeps only the `showBubble` gate (see §3). Border, corner radius (token),
and RTL corner mirroring all follow **upstream v5** — no visual fork divergence beyond the gate.
The previous fork look (clear border, fixed radius 12) is documented in an inline comment.

## 8. Misc

- `MessageListView.swift`: doc note about an old scrollTo-anchor experiment (behaviour = upstream).
- `LinkAttachmentView.swift`: **no functional fork change** — full upstream v5; only inline
  `- Note:` comments recording the previous image-only fork design.

## Demo & tests

- `DemoAppSwiftUI/`: `CustomAttachment`, `CustomComposerAttachmentView`, `ViewFactoryExamples`,
  `AppleMessageComposerView` — adopt the `layout` param / options form / iOS-15 cleanup.
- `StreamChatSwiftUITests/`: `MessageListView_Tests` keeps the fork's system-message snapshot tests
  (+78 lines); `ViewFactory_Tests` passes `layout: .all`.
- All message-render snapshots need re-recording (layout changed).

## Reconciling on the next upstream bump — risk order

1. **Custom-attachment `layout` API** — public protocol/options surface; conflicts hard.
2. **`MessageView` composition** — upstream reworks message rendering frequently.
3. **`showBubble` plumbing** — spans `MessageItemView`/`MessageContainerView`/`MessageView`/`MessageBubble`/`Styles`.
4. **Padding/spacer** (`MessageItemView`, `MessageContainerView`), **reactions offset**.
5. Platform availability, composer alignment, misc — usually trivial.
