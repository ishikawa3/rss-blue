import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID = UUID()
    var title: String = ""
    var contentHTML: String?
    var summary: String?
    var url: URL?
    var author: String?
    var publishedDate: Date?
    var isRead: Bool = false
    var isStarred: Bool = false

    // CloudKit requires optional relationships
    var feed: Feed?

    init(title: String, feed: Feed? = nil) {
        self.id = UUID()
        self.title = title
        self.feed = feed
        self.isRead = false
        self.isStarred = false
    }
}
