import Foundation
import SwiftData

@Model
final class Feed {
    var id: UUID
    var title: String
    var url: URL
    var homePageURL: URL?
    var feedDescription: String?
    var iconData: Data?
    var lastUpdated: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]?
    
    var unreadCount: Int {
        articles?.filter { !$0.isRead }.count ?? 0
    }
    
    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.url = url
    }
}
