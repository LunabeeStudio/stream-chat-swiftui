//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

@testable import StreamChat
@testable import StreamChatSwiftUI
import XCTest

class MessageComposerViewModel_Tests: StreamChatTestCase {
    
    private let testImage = UIImage(systemName: "checkmark")!
    private var mockURL: URL!
    
    private var defaultAsset: AddedAsset {
        AddedAsset(
            image: testImage,
            id: .unique,
            url: mockURL,
            type: .image
        )
    }
    
    override func setUp() {
        super.setUp()
        mockURL = generateURL()
        writeMockData(for: mockURL)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        if let mockURL = mockURL {
            try? FileManager.default.removeItem(at: mockURL)
        }
        await chatClient.logout()
    }
    
    @MainActor func test_messageComposerVM_sendButtonDisabled() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        let buttonEnabled = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(buttonEnabled == false)
    }
    
    @MainActor func test_messageComposerVM_emptySpaceButtonDisabled() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.text = "      "
        
        // Then
        XCTAssert(viewModel.sendButtonEnabled == false)
    }
    
    @MainActor func test_messageComposerVM_sendButtonEnabled_textChange() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.text = "test"
        let buttonEnabled = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(buttonEnabled == true)
        XCTAssert(viewModel.pickerTypeState == .collapsed)
    }
    
    @MainActor func test_messageComposerVM_sendButtonEnabled_addedAsset() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.imageTapped(defaultAsset)
        let buttonEnabled = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(buttonEnabled == true)
        XCTAssertEqual(viewModel.addedAssets.count, 1)
    }
    
    @MainActor func test_messageComposerVM_sendButtonEnabled_addedFile() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.addedFileURLs.append(mockURL)
        let buttonEnabled = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(buttonEnabled == true)
        XCTAssertEqual(viewModel.addedFileURLs.count, 1)
    }
    
    @MainActor func test_messageComposerVM_sendButtonEnabled_addedCustomAttachment() {
        // Given
        let viewModel = makeComposerViewModel()
        let attachment = CustomAttachment(id: .unique, content: .mockFile)
        
        // When
        viewModel.customAttachmentTapped(attachment)
        let buttonEnabled = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(buttonEnabled == true)
        XCTAssertEqual(viewModel.addedCustomAttachments.count, 1)
    }
    
    @MainActor func test_messageComposerVM_changePickerState() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.change(pickerState: .custom)
        
        // Then
        XCTAssert(viewModel.pickerState == .custom)
    }
    
    @MainActor func test_messageComposerVM_inputComposerNotScrollable() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.imageTapped(defaultAsset)
        let inputComposerScrollable = viewModel.inputComposerShouldScroll
        
        // Then
        XCTAssert(inputComposerScrollable == false)
    }
    
    @MainActor func test_messageComposerVM_inputComposerScrollableAttachments() {
        // Given
        let viewModel = makeComposerViewModel()
        let attachments = [
            CustomAttachment(id: .unique, content: .mockFile),
            CustomAttachment(id: .unique, content: .mockImage),
            CustomAttachment(id: .unique, content: .mockVideo),
            CustomAttachment(id: .unique, content: .mockVideo)
        ]
        
        // When
        viewModel.addedCustomAttachments = attachments
        let inputComposerScrollable = viewModel.inputComposerShouldScroll
        
        // Then
        XCTAssert(inputComposerScrollable == true)
    }
    
    @MainActor func test_messageComposerVM_inputComposerScrollableFiles() {
        // Given
        let viewModel = makeComposerViewModel()
        let attachments: [URL] = [mockURL, mockURL, mockURL]
        
        // When
        viewModel.addedFileURLs = attachments
        let inputComposerScrollable = viewModel.inputComposerShouldScroll
        
        // Then
        XCTAssert(inputComposerScrollable == true)
    }
    
    @MainActor func test_messageComposerVM_imageRemovalByTappingTwice() {
        // Given
        let viewModel = makeComposerViewModel()
        let asset = defaultAsset
        
        // When
        viewModel.imageTapped(asset) // added to the attachments list
        viewModel.imageTapped(asset) // removed from the attachments list
        
        // Then
        XCTAssert(viewModel.addedAssets.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_removeFileAttachment() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.addedFileURLs = [mockURL]
        viewModel.removeAttachment(with: mockURL.absoluteString)
        
        // Then
        XCTAssert(viewModel.addedFileURLs.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_removeImageAttachment() {
        // Given
        let viewModel = makeComposerViewModel()
        let asset = defaultAsset
        
        // When
        viewModel.imageTapped(asset)
        viewModel.removeAttachment(with: asset.id)
        
        // Then
        XCTAssert(viewModel.addedAssets.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_cameraImageAdded() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.cameraImageAdded(defaultAsset)
        
        // Then
        XCTAssertEqual(viewModel.addedAssets.count, 1)
        XCTAssert(viewModel.pickerState == .photos)
    }
    
    @MainActor func test_messageComposerVM_imageIsSelected() {
        // Given
        let viewModel = makeComposerViewModel()
        let asset = defaultAsset
        
        // When
        viewModel.imageTapped(asset)
        let imageIsSelected = viewModel.isImageSelected(with: asset.id)
        
        // Then
        XCTAssert(imageIsSelected == true)
    }
    
    @MainActor func test_messageComposerVM_imageIsNotSelected() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.imageTapped(defaultAsset)
        let imageSelected = viewModel.isImageSelected(with: .unique)
        
        // Then
        XCTAssert(imageSelected == false)
    }
    
    @MainActor func test_messageComposerVM_customAttachmentSelected() {
        // Given
        let viewModel = makeComposerViewModel()
        let attachment = CustomAttachment(id: .unique, content: .mockFile)
        
        // When
        viewModel.customAttachmentTapped(attachment)
        let isSelected = viewModel.isCustomAttachmentSelected(attachment)
        
        // Then
        XCTAssert(isSelected == true)
    }
    
    @MainActor func test_messageComposerVM_customAttachmentRemovalByTappingTwice() {
        // Given
        let viewModel = makeComposerViewModel()
        let attachment = CustomAttachment(id: .unique, content: .mockFile)
        
        // When
        viewModel.customAttachmentTapped(attachment)
        viewModel.customAttachmentTapped(attachment)
        let isSelected = viewModel.isCustomAttachmentSelected(attachment)
        
        // Then
        XCTAssert(isSelected == false)
        XCTAssert(viewModel.addedCustomAttachments.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_cameraPickerShown() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerState = .camera
        
        // Then
        XCTAssert(viewModel.cameraPickerShown == true)
    }
    
    @MainActor func test_messageComposerVM_filePickerShown() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerState = .files
        
        // Then
        XCTAssert(viewModel.filePickerShown == true)
    }
    
    @MainActor func test_messageComposerVM_overlayNotShown() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerTypeState = .expanded(.none)
        let overlayShown = viewModel.overlayShown
        
        // Then
        XCTAssert(overlayShown == false)
    }
    
    @MainActor func test_messageComposerVM_overlayShown() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerTypeState = .expanded(.media)
        let overlayShown = viewModel.overlayShown
        
        // Then
        XCTAssert(overlayShown == true)
    }
    
    @MainActor func test_messageComposerVM_sendNewMessage() async throws {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.text = "test"
        viewModel.imageTapped(defaultAsset)
        viewModel.addedFileURLs = [mockURL]
        viewModel.sendMessage(
            quotedMessage: nil,
            editedMessage: nil
        ) {
            // Then
            Task {
                try await waitForTask(nanoseconds: 1_000_000_000)
                XCTAssertEqual(viewModel.errorShown, false)
                XCTAssertEqual(viewModel.text, "")
                XCTAssert(viewModel.addedAssets.isEmpty)
                XCTAssert(viewModel.addedFileURLs.isEmpty)
            }
        }
    }
    
    @MainActor func test_messageComposerVM_notInThread() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        let sendInChannel = viewModel.sendInChannelShown
        let isDMChannel = viewModel.isDirectChannel
        
        // Then
        XCTAssert(sendInChannel == false)
        XCTAssert(isDMChannel == true)
    }
    
    @MainActor func test_messageComposerVM_inThread() {
        // Given
        let chat = ChatChannelTestHelpers.makeChat(chatClient: chatClient)
        let viewModel = MessageComposerViewModel(
            chat: chat,
            messageId: .unique
        )
        
        // When
        let sendInChannel = viewModel.sendInChannelShown
        let isDMChannel = viewModel.isDirectChannel
        
        // Then
        XCTAssert(sendInChannel == true)
        XCTAssert(isDMChannel == true)
    }
    
    @MainActor func test_messageComposerVM_settingComposerCommand() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.text = "/giphy"
        
        // Then
        XCTAssert(viewModel.composerCommand != nil)
        XCTAssert(viewModel.composerCommand?.id == "/giphy")
    }
    
    @MainActor func test_messageComposerVM_instantCommandsShown() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerTypeState = .expanded(.instantCommands)
        
        // Then
        XCTAssert(viewModel.composerCommand != nil)
        XCTAssert(viewModel.composerCommand?.id == "instantCommands")
    }
    
    @MainActor func test_messageComposerVM_giphySendButtonEnabled() {
        // Given
        let viewModel = makeComposerViewModel()
        let command = ComposerCommand(
            id: "/giphy",
            typingSuggestion: TypingSuggestion(
                text: "/giphy",
                locationRange: NSRange(location: 1, length: 5)
            ),
            displayInfo: CommandDisplayInfo(
                displayName: "Giphy",
                icon: UIImage(systemName: "xmark")!,
                format: "/giphy [text]",
                isInstant: true
            )
        )
        
        // When
        viewModel.composerCommand = command
        let initialSendButtonState = viewModel.sendButtonEnabled
        viewModel.text = "hey"
        let finalSendButtonState = viewModel.sendButtonEnabled
        
        // Then
        XCTAssert(initialSendButtonState == false)
        XCTAssert(finalSendButtonState == true)
    }
    
    @MainActor func test_messageComposerVM_suggestionsShown() async throws {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.pickerTypeState = .expanded(.instantCommands)
        try await waitForTask(nanoseconds: 500_000_000)
        
        // Then
        XCTAssert(!viewModel.suggestions.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_maxAttachmentsAssets() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        for _ in 0..<10 {
            let newAsset = defaultAsset
            viewModel.imageTapped(newAsset)
        }
        let newAsset = defaultAsset
        viewModel.imageTapped(newAsset) // This one will not be added, default limit is 10.

        // Then
        XCTAssertEqual(viewModel.addedAssets.count, 10)
    }
    
    @MainActor func test_messageComposerVM_maxAttachmentsCombined() {
        // Given
        let viewModel = makeComposerViewModel()
        var urls = [URL]()
        
        // When
        for _ in 0..<5 {
            let newAsset = defaultAsset
            viewModel.imageTapped(newAsset)
        }
        for _ in 0..<5 {
            let newURL = generateURL()
            writeMockData(for: newURL)
            urls.append(newURL)
            viewModel.addedFileURLs.append(newURL)
        }
        let newAsset = defaultAsset
        viewModel.imageTapped(newAsset) // This one will not be added, default limit is 10.
        let newURL = generateURL()
        viewModel.addedFileURLs.append(newURL)
        
        // Then
        let total = viewModel.addedAssets.count + viewModel.addedFileURLs.count
        XCTAssertEqual(total, 10)
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    @MainActor func test_messageComposerVM_maxSizeExceeded() {
        // Given
        let viewModel = makeComposerViewModel()
        let cdnClient = CDNClient_Mock()
        CDNClient_Mock.maxAttachmentSize = 5
        let client = ChatClient.mock(customCDNClient: cdnClient)
        streamChat = StreamChat(chatClient: client)
        
        // When
        let newAsset = defaultAsset
        viewModel.imageTapped(newAsset) // will not be added because of small max attachment size.
        let alertShown = viewModel.attachmentSizeExceeded
        
        // Then
        XCTAssert(viewModel.addedAssets.isEmpty)
        XCTAssert(alertShown == true)
    }
    
    @MainActor func test_messageComposerVM_mentionUsers() {
        // Given
        let viewModel = makeComposerViewModel()
        let command = ComposerCommand(
            id: "mentions",
            typingSuggestion: TypingSuggestion(text: "Hey @Martin", locationRange: NSRange(location: 0, length: 11)),
            displayInfo: nil
        )
        let user = ChatUser.mock(id: .unique, name: "Martin")
        
        // When
        viewModel.handleCommand(
            for: .constant("Hey @Martin"),
            selectedRangeLocation: .constant(11),
            command: .constant(command),
            extraData: ["chatUser": user]
        )
        
        // Then
        XCTAssertEqual(viewModel.mentionedUsers.count, 1)
        XCTAssert(viewModel.mentionedUsers.first?.name == "Martin")
    }
    
    @MainActor func test_messageComposerVM_noMentionedUsers() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // When
        viewModel.handleCommand(
            for: .constant("Hey Martin"),
            selectedRangeLocation: .constant(10),
            command: .constant(nil),
            extraData: [:]
        )
        
        // Then
        XCTAssert(viewModel.mentionedUsers.isEmpty)
    }
    
    @MainActor func test_messageComposerVM_mentionedUsersClearText() {
        // Given
        let viewModel = makeComposerViewModel()
        let command = ComposerCommand(
            id: "mentions",
            typingSuggestion: TypingSuggestion(text: "Hey @Martin", locationRange: NSRange(location: 0, length: 11)),
            displayInfo: nil
        )
        let user = ChatUser.mock(id: .unique, name: "Martin")
        
        // When
        viewModel.handleCommand(
            for: .constant("Hey @Martin"),
            selectedRangeLocation: .constant(11),
            command: .constant(command),
            extraData: ["chatUser": user]
        )
        viewModel.text = ""
        
        // Then
        XCTAssert(viewModel.mentionedUsers.isEmpty)
    }
    
    @MainActor func test_addedAsset_extraData() {
        // Given
        let image = UIImage(systemName: "person")!
        let url = URL.newTemporaryFileURL()
        let addedAsset = AddedAsset(
            image: image,
            id: "imageId",
            url: url,
            type: .image,
            extraData: ["test": "test"]
        )
        
        // When
        try! image.pngData()?.write(to: url)
        let attachment = try! addedAsset.toAttachmentPayload()
        let payload = attachment.payload as! ImageAttachmentPayload
        let extraData = payload.extraData
        
        // Then
        XCTAssert(extraData?["test"] == "test")
        try! FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Recording
    
    @MainActor func test_messageComposer_discardRecording() {
        // Given
        let viewModel = makeComposerViewModel()
        viewModel.recordingState = .recording(.zero)
        
        // When
        viewModel.discardRecording()
        
        // Then
        XCTAssert(viewModel.recordingState == .initial)
        XCTAssert(viewModel.audioRecordingInfo == .initial)
    }
    
    @MainActor func test_messageComposer_confirmStoppedRecording() {
        // Given
        let viewModel = makeComposerViewModel()
        viewModel.recordingState = .stopped
        viewModel.pendingAudioRecording = AddedVoiceRecording(
            url: .localYodaImage,
            duration: 1,
            waveform: [0, 1]
        )
        
        // When
        viewModel.confirmRecording()
        
        // Then
        XCTAssert(viewModel.recordingState == .initial)
        XCTAssert(viewModel.audioRecordingInfo == .initial)
        XCTAssertEqual(viewModel.addedVoiceRecordings.count, 1)
        XCTAssert(viewModel.pendingAudioRecording == nil)
    }
    
    @MainActor func test_messageComposer_previewRecording() {
        // Given
        let viewModel = makeComposerViewModel()
        viewModel.recordingState = .recording(.zero)
        
        // When
        viewModel.previewRecording()
        
        // Then
        XCTAssert(viewModel.recordingState == .stopped)
    }
    
    @MainActor func test_messageComposer_lockRecording() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // Then
        viewModel.recordingState = .recording(.init(x: 0, y: RecordingConstants.lockMaxDistance - 1))
        
        // Then
        XCTAssert(viewModel.recordingState == .locked)
    }
    
    @MainActor func test_messageComposer_cancelRecording() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // Then
        viewModel.recordingState = .recording(.init(x: RecordingConstants.cancelMaxDistance - 1, y: 0))
        
        // Then
        XCTAssert(viewModel.recordingState == .initial)
        XCTAssert(viewModel.recordingState.showsComposer == true)
    }
    
    @MainActor func test_messageComposer_updateRecordingInfo() {
        // Given
        let viewModel = makeComposerViewModel()
        
        // Then
        let context = AudioRecordingContext(state: .recording, duration: 2.0, averagePower: 1.0)
        viewModel.audioRecorder(viewModel.audioRecorder, didUpdateContext: context)
        
        // Then
        XCTAssertEqual(viewModel.audioRecordingInfo.duration, 2.0)
        XCTAssert(viewModel.audioRecordingInfo.waveform == [1.0])
    }
    
    @MainActor func test_messageComposer_recordingError() {
        // Given
        let viewModel = makeComposerViewModel()
        viewModel.recordingState = .recording(.zero)
        
        // Then
        viewModel.audioRecorder(viewModel.audioRecorder, didFailWithError: ClientError.Unexpected())
        
        // Then
        XCTAssert(viewModel.recordingState == .initial)
        XCTAssert(viewModel.audioRecordingInfo == .initial)
    }
    
    // MARK: - private
    
    @MainActor private func makeComposerViewModel() -> MessageComposerViewModel {
        MessageComposerTestUtils.makeComposerViewModel(chatClient: chatClient)
    }
    
    @MainActor private func makeChannelController(
        messages: [ChatMessage] = []
    ) -> Chat_Mock {
        MessageComposerTestUtils.makeChat(
            chatClient: chatClient,
            messages: messages
        )
    }
    
    private func generateURL() -> URL {
        NSURL.fileURL(
            withPath: NSTemporaryDirectory() + UUID().uuidString + ".png"
        )
    }
    
    private func writeMockData(for url: URL) {
        let data = UIImage(systemName: "checkmark")?.pngData()
        try? data?.write(to: url)
    }
}

enum MessageComposerTestUtils {
    @MainActor static func makeComposerViewModel(chatClient: ChatClient) -> MessageComposerViewModel {
        let chat = makeChat(chatClient: chatClient)
        let viewModel = MessageComposerViewModel(
            chat: chat,
            messageId: nil
        )
        return viewModel
    }
    
    @MainActor static func makeChat(
        chatClient: ChatClient,
        messages: [ChatMessage] = []
    ) -> Chat_Mock {
        ChatChannelTestHelpers.makeChat(
            chatClient: chatClient,
            messages: messages
        )
    }
}
