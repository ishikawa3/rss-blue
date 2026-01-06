import SwiftUI

// MARK: - Focused Values

/// 選択中の記事を伝播するためのFocusedValueKey
struct FocusedArticleKey: FocusedValueKey {
    typealias Value = Binding<Article?>
}

/// 選択中のFeedSelectionを伝播するためのFocusedValueKey
struct FocusedFeedSelectionKey: FocusedValueKey {
    typealias Value = Binding<FeedSelection?>
}

/// 新規購読追加を表示するためのFocusedValueKey
struct ShowAddFeedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

/// リフレッシュアクションを伝播するためのFocusedValueKey
struct RefreshActionKey: FocusedValueKey {
    typealias Value = () async -> Void
}

/// 全記事を既読にするアクションを伝播するためのFocusedValueKey
struct MarkAllAsReadActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var selectedArticle: Binding<Article?>? {
        get { self[FocusedArticleKey.self] }
        set { self[FocusedArticleKey.self] = newValue }
    }

    var feedSelection: Binding<FeedSelection?>? {
        get { self[FocusedFeedSelectionKey.self] }
        set { self[FocusedFeedSelectionKey.self] = newValue }
    }

    var showAddFeed: Binding<Bool>? {
        get { self[ShowAddFeedKey.self] }
        set { self[ShowAddFeedKey.self] = newValue }
    }

    var refreshAction: (() async -> Void)? {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }

    var markAllAsReadAction: (() -> Void)? {
        get { self[MarkAllAsReadActionKey.self] }
        set { self[MarkAllAsReadActionKey.self] = newValue }
    }
}
