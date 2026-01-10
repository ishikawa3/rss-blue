import Foundation
import UserNotifications

#if os(iOS)
    import UIKit
#endif

/// Service for managing push notifications for new articles
final class NotificationService: NSObject, @unchecked Sendable {
    static let shared = NotificationService()

    /// Notification category identifier for article notifications
    static let articleCategoryIdentifier = "NEW_ARTICLE"

    /// User info keys for notification payload
    enum UserInfoKey {
        static let articleId = "articleId"
        static let feedId = "feedId"
    }

    /// Callback when user taps on a notification
    var onNotificationTapped: ((String) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Request notification permissions from the user
    @MainActor
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await setupNotificationCategories()
                center.delegate = self
            }

            return granted
        } catch {
            print("[Notification] Authorization request failed: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Setup notification categories and actions
    private func setupNotificationCategories() async {
        let openAction = UNNotificationAction(
            identifier: "OPEN_ARTICLE",
            title: "Open",
            options: [.foreground]
        )

        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ",
            title: "Mark as Read",
            options: []
        )

        let articleCategory = UNNotificationCategory(
            identifier: Self.articleCategoryIdentifier,
            actions: [openAction, markReadAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([articleCategory])
    }

    // MARK: - Sending Notifications

    /// Send notification for new articles
    /// - Parameters:
    ///   - articles: Array of new articles with their feed info
    ///   - feedTitle: The title of the feed
    func sendNewArticleNotifications(
        articles: [(id: String, title: String, feedId: String, feedTitle: String)]
    ) async {
        let status = await checkAuthorizationStatus()
        guard status == .authorized else { return }

        // Check if notifications are enabled in settings
        let notificationsEnabled = await MainActor.run {
            UserDefaults.standard.bool(forKey: "notificationsEnabled")
        }

        // Default to true if not set
        let enabled =
            UserDefaults.standard.object(forKey: "notificationsEnabled") == nil
            ? true : notificationsEnabled
        guard enabled else { return }

        // Group articles by feed
        var articlesByFeed: [String: [(id: String, title: String)]] = [:]
        var feedTitles: [String: String] = [:]

        for article in articles {
            if articlesByFeed[article.feedId] == nil {
                articlesByFeed[article.feedId] = []
                feedTitles[article.feedId] = article.feedTitle
            }
            articlesByFeed[article.feedId]?.append((id: article.id, title: article.title))
        }

        // Send grouped notifications per feed
        for (feedId, feedArticles) in articlesByFeed {
            guard let feedTitle = feedTitles[feedId] else { continue }

            if feedArticles.count == 1 {
                // Single article notification
                let article = feedArticles[0]
                await sendSingleArticleNotification(
                    articleId: article.id,
                    articleTitle: article.title,
                    feedId: feedId,
                    feedTitle: feedTitle
                )
            } else {
                // Multiple articles - send summary notification
                await sendMultipleArticlesNotification(
                    articles: feedArticles,
                    feedId: feedId,
                    feedTitle: feedTitle
                )
            }
        }
    }

    /// Send notification for a single new article
    private func sendSingleArticleNotification(
        articleId: String,
        articleTitle: String,
        feedId: String,
        feedTitle: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = feedTitle
        content.body = articleTitle
        content.sound = .default
        content.categoryIdentifier = Self.articleCategoryIdentifier
        content.threadIdentifier = feedId  // Group by feed
        content.userInfo = [
            UserInfoKey.articleId: articleId,
            UserInfoKey.feedId: feedId,
        ]

        let request = UNNotificationRequest(
            identifier: "article-\(articleId)",
            content: content,
            trigger: nil  // Immediate delivery
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[Notification] Sent notification for article: \(articleTitle)")
        } catch {
            print("[Notification] Failed to send notification: \(error)")
        }
    }

    /// Send summary notification for multiple new articles from same feed
    private func sendMultipleArticlesNotification(
        articles: [(id: String, title: String)],
        feedId: String,
        feedTitle: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = feedTitle
        content.body = "\(articles.count) new articles"
        content.sound = .default
        content.categoryIdentifier = Self.articleCategoryIdentifier
        content.threadIdentifier = feedId

        // Include first article ID for opening
        if let firstArticle = articles.first {
            content.userInfo = [
                UserInfoKey.articleId: firstArticle.id,
                UserInfoKey.feedId: feedId,
            ]
        }

        // Add article titles to the notification summary
        #if os(iOS)
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .active
            }
        #endif

        let request = UNNotificationRequest(
            identifier: "feed-\(feedId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print(
                "[Notification] Sent summary notification for \(articles.count) articles from \(feedTitle)"
            )
        } catch {
            print("[Notification] Failed to send summary notification: \(error)")
        }
    }

    // MARK: - Badge Management

    /// Update app badge with unread count
    @MainActor
    func updateBadge(unreadCount: Int) {
        #if os(iOS)
            UNUserNotificationCenter.current().setBadgeCount(unreadCount)
        #endif
    }

    /// Clear all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        guard let articleId = userInfo[UserInfoKey.articleId] as? String else {
            return
        }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier, "OPEN_ARTICLE":
            // User tapped on notification or "Open" action
            await MainActor.run {
                onNotificationTapped?(articleId)
            }

        case "MARK_READ":
            // Mark article as read without opening
            await markArticleAsRead(articleId: articleId)

        default:
            break
        }
    }

    /// Mark article as read (called from notification action)
    @MainActor
    private func markArticleAsRead(articleId: String) async {
        // This will be implemented when we have access to the model context
        print("[Notification] Mark as read: \(articleId)")
    }
}
