import Foundation

/// Represents what is selected in the sidebar
enum FeedSelection: Hashable {
    case allUnread
    case today
    case starred
    case feed(Feed)

    var title: String {
        switch self {
        case .allUnread:
            return "All Unread"
        case .today:
            return "Today"
        case .starred:
            return "Starred"
        case .feed(let feed):
            return feed.title
        }
    }

    var systemImage: String {
        switch self {
        case .allUnread:
            return "circle.badge"
        case .today:
            return "calendar"
        case .starred:
            return "star.fill"
        case .feed:
            return "dot.radiowaves.up.forward"
        }
    }
}
