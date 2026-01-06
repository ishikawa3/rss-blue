import SwiftUI

// MARK: - Article Commands

/// 記事操作のメニューコマンド
struct ArticleCommands: Commands {
    @FocusedValue(\.selectedArticle) var selectedArticle

    var body: some Commands {
        CommandMenu("Article") {
            Button("Toggle Read") {
                selectedArticle?.wrappedValue?.isRead.toggle()
            }
            .keyboardShortcut("u", modifiers: [])
            .disabled(selectedArticle?.wrappedValue == nil)

            Button("Toggle Star") {
                selectedArticle?.wrappedValue?.isStarred.toggle()
            }
            .keyboardShortcut("s", modifiers: [])
            .disabled(selectedArticle?.wrappedValue == nil)

            Divider()

            Button("Open in Browser") {
                if let url = selectedArticle?.wrappedValue?.url {
                    #if os(macOS)
                        NSWorkspace.shared.open(url)
                    #endif
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(selectedArticle?.wrappedValue?.url == nil)
        }
    }
}

// MARK: - Go Commands

/// ナビゲーションのメニューコマンド
struct GoCommands: Commands {
    @FocusedValue(\.feedSelection) var feedSelection

    var body: some Commands {
        CommandMenu("Go") {
            Button("All Unread") {
                feedSelection?.wrappedValue = .allUnread
            }
            .keyboardShortcut("1", modifiers: [])

            Button("Today") {
                feedSelection?.wrappedValue = .today
            }
            .keyboardShortcut("2", modifiers: [])

            Button("Starred") {
                feedSelection?.wrappedValue = .starred
            }
            .keyboardShortcut("3", modifiers: [])
        }
    }
}

// MARK: - Subscription Commands

/// 購読操作のメニューコマンド
struct SubscriptionCommands: Commands {
    @FocusedValue(\.refreshAction) var refreshAction
    @FocusedValue(\.markAllAsReadAction) var markAllAsReadAction
    @FocusedValue(\.showAddFeed) var showAddFeed

    var body: some Commands {
        CommandMenu("Subscription") {
            Button("New Subscription...") {
                showAddFeed?.wrappedValue = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Refresh All") {
                Task {
                    await refreshAction?()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Mark All as Read") {
                markAllAsReadAction?()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
    }
}

// MARK: - View Commands

/// 表示操作のメニューコマンド
struct ViewCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .sidebar) {
            // サイドバーの表示/非表示は標準で提供される
        }
    }
}
