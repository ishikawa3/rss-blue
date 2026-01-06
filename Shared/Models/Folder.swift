import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var isExpanded: Bool = true

    @Relationship(deleteRule: .nullify, inverse: \Feed.folder)
    var feeds: [Feed]?

    /// Total unread count across all feeds in this folder
    var unreadCount: Int {
        feeds?.reduce(0) { $0 + $1.unreadCount } ?? 0
    }

    /// All articles from feeds in this folder
    var allArticles: [Article] {
        feeds?.flatMap { $0.articles ?? [] } ?? []
    }

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
    }
}
