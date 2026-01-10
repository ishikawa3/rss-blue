import Foundation

/// Shared data model for widget - lightweight version of Article
struct WidgetArticle: Codable, Identifiable {
    let id: String
    let title: String
    let feedTitle: String
    let publishedDate: Date?
    let isRead: Bool

    init(id: String, title: String, feedTitle: String, publishedDate: Date?, isRead: Bool) {
        self.id = id
        self.title = title
        self.feedTitle = feedTitle
        self.publishedDate = publishedDate
        self.isRead = isRead
    }
}

/// Shared data container for App Groups
struct WidgetData: Codable {
    let unreadCount: Int
    let recentArticles: [WidgetArticle]
    let lastUpdated: Date

    static let empty = WidgetData(unreadCount: 0, recentArticles: [], lastUpdated: Date())
}

/// Manager for sharing data between main app and widget via App Groups
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    /// App Group identifier
    private let appGroupIdentifier = "group.com.ishikawa.rssblue"

    /// Key for storing widget data in shared UserDefaults
    private let widgetDataKey = "widgetData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    /// Save widget data to shared container
    func saveWidgetData(_ data: WidgetData) {
        guard let sharedDefaults = sharedDefaults else {
            print("[WidgetDataManager] Failed to access shared UserDefaults")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            sharedDefaults.set(encoded, forKey: widgetDataKey)
            print(
                "[WidgetDataManager] Saved widget data: \(data.unreadCount) unread, \(data.recentArticles.count) articles"
            )
        } catch {
            print("[WidgetDataManager] Failed to encode widget data: \(error)")
        }
    }

    /// Load widget data from shared container
    func loadWidgetData() -> WidgetData {
        guard let sharedDefaults = sharedDefaults,
            let data = sharedDefaults.data(forKey: widgetDataKey)
        else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(WidgetData.self, from: data)
        } catch {
            print("[WidgetDataManager] Failed to decode widget data: \(error)")
            return .empty
        }
    }
}
