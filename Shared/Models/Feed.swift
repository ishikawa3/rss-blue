import Foundation
import SwiftData

@Model
final class Feed {
    var id: UUID = UUID()
    var title: String = ""
    var urlString: String = "https://example.com"
    var homePageURL: URL?
    var feedDescription: String?
    var iconData: Data?
    var lastUpdated: Date?
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]?

    var folder: Folder?

    var url: URL {
        get { URL(string: urlString) ?? URL(string: "https://example.com")! }
        set { urlString = newValue.absoluteString }
    }

    var unreadCount: Int {
        articles?.filter { !$0.isRead }.count ?? 0
    }

    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.urlString = url.absoluteString
    }
}
