//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatSwiftUI
import SwiftUI

@main
struct DemoAppSwiftUIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Injected(\.chatClient) public var chatClient: ChatClient

    @ObservedObject var appState = AppState.shared
    @ObservedObject var notificationsHandler = NotificationsHandler.shared
    
    var channelList: ChannelList? {
        appState.channelList
    }
    
    var body: some Scene {
        WindowGroup {
            switch appState.userState {
            case .launchAnimation:
                StreamLogoLaunch()
            case .notLoggedIn:
                LoginView()
            case .loggedIn:
                if notificationsHandler.notificationChannelId != nil {
                    ChatChannelListView(
                        viewFactory: DemoAppFactory.shared,
                        channelList: channelList,
                        selectedChannelId: notificationsHandler.notificationChannelId
                    )
                } else {
                    ChatChannelListView(
                        viewFactory: DemoAppFactory.shared,
                        channelList: channelList
                    )
                }
            }
        }
        .onChange(of: appState.userState) { newValue in
            if newValue == .loggedIn {
                if let currentUserId = chatClient.currentUserId {
                    let pinnedByKey = ChatChannel.isPinnedBy(keyForUserId: currentUserId)
                    let channelListQuery = ChannelListQuery(
                        filter: .containMembers(userIds: [currentUserId]),
                        sort: [
                            .init(key: .custom(keyPath: \.isPinned, key: pinnedByKey), isAscending: true),
                            .init(key: .lastMessageAt),
                            .init(key: .updatedAt)
                        ]
                    )
                    appState.channelList = chatClient.makeChannelList(with: channelListQuery)
                }
                notificationsHandler.setupRemoteNotifications()
            }
        }
    }
}

class AppState: ObservableObject {

    @Published var userState: UserState = .launchAnimation {
        willSet {
            if newValue == .notLoggedIn && userState == .loggedIn {
                channelList = nil
            }
        }
    }
    
    var channelList: ChannelList?

    static let shared = AppState()

    private init() {}
}

enum UserState {
    case launchAnimation
    case notLoggedIn
    case loggedIn
}
