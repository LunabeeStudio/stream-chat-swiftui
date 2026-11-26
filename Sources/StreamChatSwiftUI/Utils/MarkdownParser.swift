//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

/// A parser for markdown which generates a styled attributed string.
///
/// Copy of `StreamChat.MarkdownParser` which never mutates an `AttributedString` in place: mutating an
/// `AttributedString` which has many runs (`replaceSubrange`, `insert`, `mergeAttributes`, `transformingAttributes`)
/// can trap inside Foundation ("Path out of bounds"). When a run is coalesced with the following one, the run removal
/// can rebalance the internal rope and leave a stale index behind. The runs of the parsed string are therefore copied
/// into an array of `MarkdownSegment`, every edit is done on that array, and the result is built once with `append`,
/// which only coalesces with the preceding run.
///
/// Internal, so that it shadows `StreamChat.MarkdownParser` inside this module only.
struct MarkdownParser {
    init() {}
    
    /// Creates an attributed string from a Markdown-formatted string using the provided style attributes.
    ///
    /// Apple's markdown initialiser parses markdown and adds ``NSPresentationIntent`` and ``NSInlinePresentationIntent``
    /// attributes and does not do any newline handling. All the styling related attributes (font, foregroundColor etc)
    /// and newline handling, needs to be implemented separately.
    /// UIKit and SwiftUI support different ``AttributedString`` attributes (see ``AttributeScopes.SwiftUIAttributes``,
    /// ``AttributeScopes.UIKitAttributes``, and ``AttributeScopes.FoundationAttributes``). The latter is shared by both.
    /// Therefore, we need additional parsing for presentation intent attributes and add respective style related attributes.
    ///
    /// Here is an example of a nested list which shows why we need to do such handling below (note how parent
    /// lists also show up).
    /// ```
    /// List item 1 {
    ///     NSPresentationIntent = [paragraph (id 3), listItem 1 (id 2), unorderedList (id 1)]
    /// }
    /// Nested item which is very very long and keeps going until it is wrapped {
    ///    NSPresentationIntent = [paragraph (id 6), listItem 1 (id 5), unorderedList (id 4), listItem 1 (id 2), unorderedList (id 1)]
    /// }
    /// Another nested item which is very very long and keeps going until it is wrapped {
    ///     NSPresentationIntent = [paragraph (id 9), listItem 1 (id 8), unorderedList (id 7), listItem 1 (id 5), unorderedList (id 4), listItem 1 (id 2), unorderedList (id 1)]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - markdown: The string that contains the Markdown formatting.
    ///   - options: Options that affect how the Markdown string is parsed and styled.
    ///   - attributes: The attributes to use for the whole string.
    ///   - inlinePresentationIntentAttributes: The closure for customising attributes for inline presentation intents.
    ///   - presentationIntentAttributes: The closure for customising attributes for presentation intents. Called for quote, code, list item, and headers.
    @available(iOS 15, *)
    @available(macOS 12, *)
    func style(
        markdown: String,
        options: ParsingOptions,
        attributes: AttributeContainer,
        inlinePresentationIntentAttributes: (InlinePresentationIntent) -> AttributeContainer?,
        presentationIntentAttributes: (PresentationIntent.Kind, PresentationIntent) -> AttributeContainer?
    ) throws -> AttributedString {
        var attributedString = try AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible,
                languageCode: nil
            )
        )
        
        if !attributedString.containsMarkdown() {
            // When there is no markdown, then it is just pure text. Markdown parsing drops newlines, therefore
            // we recreate the string and ignore the parsed output.
            return AttributedString(markdown, attributes: attributes)
        }
        
        var segments = attributedString.runs.map { run in
            MarkdownSegment(text: String(attributedString[run.range].characters), attributes: run.attributes)
        }
        
        // Trim newlines which remain after initial parsing (e.g. code blocks)
        segments.trimNewlines()
        
        // Default attributes
        for index in segments.indices {
            segments[index].attributes.merge(attributes)
        }
        
        // Most inline intents are handled by rendering automatically
        for (inlinePresentationIntent, range) in segments.groups(by: \.inlinePresentationIntent).reversed() {
            guard let inlinePresentationIntent else { continue }
            if let attributes = inlinePresentationIntentAttributes(inlinePresentationIntent) {
                for index in range {
                    segments[index].attributes.merge(attributes)
                }
            }
            switch inlinePresentationIntent {
            case .lineBreak:
                // Appears as a space with inline attribute, therefore we need to replace it for preserving the line break
                segments.replaceSubrange(range, with: [MarkdownSegment(text: "\n", attributes: attributes)])
            case .inlineHTML:
                // Note: there are others like: em, strong
                if segments[range].map(\.text).joined() == "<br/>" {
                    segments.replaceSubrange(range, with: [MarkdownSegment(text: "\n", attributes: attributes)])
                }
            default:
                break
            }
        }
        
        let presentationIntentEntries = segments.groups(by: \.presentationIntent).compactMap { presentationIntent, range in
            presentationIntent.map { (intent: $0, range: range) }
        }
        
        // Remove presentation intent attributes from the final string because they are handled below.
        for index in segments.indices {
            segments[index].attributes.presentationIntent = nil
        }
        
        // Segments to insert before the segment at the key index (or at the end for `segments.endIndex`). As the
        // enumeration is reversed, a later insertion at the same index goes before the earlier ones.
        var insertions: [Int: [MarkdownSegment]] = [:]
        func insert(_ text: String, attributes: AttributeContainer, at index: Int) {
            insertions[index, default: []].insert(MarkdownSegment(text: text, attributes: attributes), at: 0)
        }
        
        var previousPresentationIntentStyling: PresentationIntentStyling?
        for entry in presentationIntentEntries.reversed() {
            let presentationIntent = entry.intent
            let range = entry.range
            var presentationIntentStyling = PresentationIntentStyling(range: range, components: presentationIntent.components)
            
            for intentType in presentationIntent.components {
                switch intentType.kind {
                case .blockQuote:
                    presentationIntentStyling.quoteBlockId = intentType.identity
                    presentationIntentStyling.mergedAttributes = presentationIntentAttributes(intentType.kind, presentationIntent)
                    presentationIntentStyling.prependedString = "\u{2503}"
                case .codeBlock:
                    presentationIntentStyling.mergedAttributes = presentationIntentAttributes(intentType.kind, presentationIntent)
                    presentationIntentStyling.precedingNewlineCount += 1
                case .header:
                    presentationIntentStyling.mergedAttributes = presentationIntentAttributes(intentType.kind, presentationIntent)
                    presentationIntentStyling.precedingNewlineCount += 1
                    presentationIntentStyling.succeedingNewlineCount += 1
                case .paragraph:
                    presentationIntentStyling.paragraphId = intentType.identity
                case .listItem(ordinal: let ordinal):
                    if presentationIntentStyling.listItemOrdinal == nil {
                        presentationIntentStyling.listItemOrdinal = ordinal
                        presentationIntentStyling.mergedAttributes = presentationIntentAttributes(intentType.kind, presentationIntent)
                    }
                case .orderedList:
                    presentationIntentStyling.listId = intentType.identity
                    if presentationIntentStyling.isOrdered == nil {
                        presentationIntentStyling.isOrdered = true
                    } else {
                        presentationIntentStyling.prependedString.insert("\t", at: presentationIntentStyling.prependedString.startIndex)
                    }
                case .unorderedList:
                    presentationIntentStyling.listId = intentType.identity
                    if presentationIntentStyling.isOrdered == nil {
                        presentationIntentStyling.isOrdered = false
                    } else {
                        presentationIntentStyling.prependedString.insert("\t", at: presentationIntentStyling.prependedString.startIndex)
                    }
                case .thematicBreak, .table, .tableHeaderRow, .tableRow, .tableCell:
                    break
                @unknown default:
                    break
                }
            }
            // Paragraph applies to text and other intents
            if presentationIntentStyling.paragraphId != previousPresentationIntentStyling?.paragraphId {
                presentationIntentStyling.succeedingNewlineCount += 1
                // GitHub renderer adds another newline when paragraph changes in text
                if presentationIntentStyling.isOnlyParagraph && previousPresentationIntentStyling?.isOnlyParagraph == true {
                    presentationIntentStyling.succeedingNewlineCount += 1
                }
            }
            // More space for quotes
            switch (presentationIntentStyling.quoteBlockId, previousPresentationIntentStyling?.quoteBlockId) {
            case (.some(let current), .some(let previous)):
                presentationIntentStyling.succeedingNewlineCount += current != previous ? 1 : 0
            case (.some, .none), (.none, .some):
                presentationIntentStyling.succeedingNewlineCount += 1
            default:
                break
            }

            // Preparing list items
            if let listItemOrdinal = presentationIntentStyling.listItemOrdinal {
                if presentationIntentStyling.isOrdered == true {
                    presentationIntentStyling.prependedString.append("\(listItemOrdinal).  ")
                } else {
                    presentationIntentStyling.prependedString.append("\u{2022}  ")
                }
                // Extra space when list's last item
                if previousPresentationIntentStyling?.listId != presentationIntentStyling.listId {
                    presentationIntentStyling.succeedingNewlineCount += 1
                }
            } else {
                // Extra space when list's first item (reversed enumeration)
                if previousPresentationIntentStyling?.listId != nil {
                    presentationIntentStyling.succeedingNewlineCount += 1
                }
            }
            // Inserting additional space after the current block (reverse enumeration, therefore use the previous range)
            if presentationIntentStyling.succeedingNewlineCount > 0, let previousPresentationIntentStyling {
                let newlineString = String(repeating: "\n", count: presentationIntentStyling.succeedingNewlineCount)
                insert(newlineString, attributes: attributes, at: previousPresentationIntentStyling.range.lowerBound)
            }
            // Additional attributes
            if let attributes = presentationIntentStyling.mergedAttributes {
                for index in range {
                    segments[index].attributes.merge(attributes)
                }
            }
            // Inserting additional characters (list items etc)
            if !presentationIntentStyling.prependedString.isEmpty {
                let attributes = attributes.merging(presentationIntentStyling.mergedAttributes ?? AttributeContainer())
                if options.layoutDirectionLeftToRight {
                    insert(presentationIntentStyling.prependedString, attributes: attributes, at: range.lowerBound)
                } else {
                    insert(String(presentationIntentStyling.prependedString.reversed()), attributes: attributes, at: range.upperBound)
                }
            }
            // Spacing before the block
            if presentationIntentStyling.precedingNewlineCount > 0, range.lowerBound != segments.startIndex {
                let newlineString = String(repeating: "\n", count: presentationIntentStyling.precedingNewlineCount)
                insert(newlineString, attributes: attributes, at: range.lowerBound)
            }
            
            previousPresentationIntentStyling = presentationIntentStyling
        }
        
        var result = AttributedString()
        for index in 0...segments.count {
            var orderedSegments = insertions[index] ?? []
            if index < segments.endIndex {
                orderedSegments.append(segments[index])
            }
            for segment in orderedSegments {
                var attributes = segment.attributes
                // Support links like "getstream.io" (URL parsing considers it as a path, not host)
                if let url = attributes.link, url.scheme == nil, url.host == nil,
                   let urlWithScheme = URL(string: "https://" + url.absoluteString) {
                    attributes.link = urlWithScheme
                }
                result.append(AttributedString(segment.text, attributes: attributes))
            }
        }
        return result
    }
}

@available(iOS 15, *)
@available(macOS 12, *)
extension MarkdownParser {
    /// Options that affect how the Markdown string is parsed and styled.
    struct ParsingOptions {
        init(layoutDirectionLeftToRight: Bool = true) {
            self.layoutDirectionLeftToRight = layoutDirectionLeftToRight
        }
        
        /// Affects insertion index for additional characters like bullets and numbers for lists.
        var layoutDirectionLeftToRight = true
    }
}

@available(iOS 15, *)
@available(macOS 12, *)
private extension AttributedString {
    /// True, if it contains markdown, otherwise false.
    ///
    /// - Note: Use it only after creating the attributed string with markdown initializer.
    func containsMarkdown() -> Bool {
        let containsInlineIntents = runs[\.inlinePresentationIntent].contains(where: { inlineIntent, _ in
            switch inlineIntent {
            case .none, .some(.softBreak):
                return false
            default:
                return true
            }
        })
        if containsInlineIntents {
            return true
        }
        let containsPresentationIntents = runs[\.presentationIntent].contains(where: { intent, _ in
            switch intent {
            case .none:
                return false
            case .some(let intent):
                // Regular text gets paragraphs
                return !intent.components.allSatisfy { $0.kind == .paragraph }
            }
        })
        if containsPresentationIntents {
            return true
        }
        // Markdown links get the same link attribute
        return runs[\.link].contains(where: { link, _ in link != nil })
    }
}

// Note: newlines are used instead of paragraph style because SwiftUI does render paragraph styles
@available(iOS 15.0, *)
@available(macOS 12, *)
private struct PresentationIntentStyling {
    let range: Range<Int>
    let components: [PresentationIntent.IntentType]
    var paragraphId: Int?
    var quoteBlockId: Int?
    var precedingNewlineCount = 0
    var succeedingNewlineCount = 0
    var mergedAttributes: AttributeContainer?
    var prependedString = ""
    var listItemOrdinal: Int?
    var listId: Int?
    var isOrdered: Bool?
    
    var isOnlyParagraph: Bool {
        components.count == 1 &&
            components.allSatisfy { $0.kind == .paragraph }
    }
}

/// A run of the parsed markdown: its text and its attributes.
@available(iOS 15.0, *)
@available(macOS 12, *)
private struct MarkdownSegment {
    var text: String
    var attributes: AttributeContainer
}

@available(iOS 15.0, *)
@available(macOS 12, *)
private extension Array where Element == MarkdownSegment {
    /// Ranges of adjacent segments sharing the same attribute value, like `AttributedString.runs[keyPath]`.
    func groups<Value: Equatable>(
        by keyPath: KeyPath<AttributeContainer, Value?>
    ) -> [(value: Value?, range: Range<Int>)] {
        var groups: [(value: Value?, range: Range<Int>)] = []
        for index in indices {
            let value = self[index].attributes[keyPath: keyPath]
            if let last = groups.last, last.value == value {
                groups[groups.count - 1].range = last.range.lowerBound..<(index + 1)
            } else {
                groups.append((value, index..<(index + 1)))
            }
        }
        return groups
    }
    
    mutating func trimNewlines() {
        guard contains(where: { $0.text.contains { !$0.isNewline } }) else { return }
        while self[startIndex].text.first?.isNewline == true {
            self[startIndex].text.removeFirst()
            if self[startIndex].text.isEmpty {
                removeFirst()
            }
        }
        while self[endIndex - 1].text.last?.isNewline == true {
            self[endIndex - 1].text.removeLast()
            if self[endIndex - 1].text.isEmpty {
                removeLast()
            }
        }
    }
}
