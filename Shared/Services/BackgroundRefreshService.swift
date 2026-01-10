import Foundation
import Network
import SwiftData
import UserNotifications

#if os(iOS)
    import BackgroundTasks
    import UIKit
#endif

/// Service for managing background feed refresh operations
final class BackgroundRefreshService: @unchecked Sendable {
    static let shared = BackgroundRefreshService()

    /// Background task identifier for iOS
    static let taskIdentifier = "com.ishikawa.rssblue.refresh"

    /// Minimum interval between background refreshes (in seconds)
    private static let minimumRefreshInterval: TimeInterval = 15 * 60  // 15 minutes

    /// Network path monitor for checking connectivity
    private let networkMonitor = NWPathMonitor()
    private var isConnectedToWiFi = false
    private var isConnectedToNetwork = false

    /// Model container reference (set by the app)
    weak var modelContainer: ModelContainer?

    /// User preferences
    @MainActor
    private var refreshOnWiFiOnly: Bool {
        UserDefaults.standard.bool(forKey: "refreshOnWiFiOnly")
    }

    @MainActor
    private var refreshInterval: Int {
        UserDefaults.standard.integer(forKey: "refreshInterval")
    }

    private init() {
        setupNetworkMonitor()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnectedToNetwork = path.status == .satisfied
            self?.isConnectedToWiFi = path.usesInterfaceType(.wifi)
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: - iOS Background Tasks

    #if os(iOS)
        /// Register background task handler with the system
        /// Call this from AppDelegate or App init
        func registerBackgroundTask() {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: Self.taskIdentifier,
                using: nil
            ) { task in
                self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }

        /// Schedule the next background refresh
        @MainActor
        func scheduleBackgroundRefresh() {
            let interval = refreshInterval

            // Don't schedule if manual refresh only
            guard interval > 0 else {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
                return
            }

            let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(interval * 60))

            do {
                try BGTaskScheduler.shared.submit(request)
                print("[BackgroundRefresh] Scheduled next refresh in \(interval) minutes")
            } catch {
                print("[BackgroundRefresh] Failed to schedule: \(error)")
            }
        }

        /// Handle background task execution
        private func handleBackgroundTask(_ task: BGAppRefreshTask) {
            // Schedule the next refresh first
            Task { @MainActor in
                scheduleBackgroundRefresh()
            }

            // Create a task to perform the refresh
            let refreshTask = Task {
                await performBackgroundRefresh()
            }

            // Set expiration handler
            task.expirationHandler = {
                refreshTask.cancel()
            }

            // Complete the task when refresh is done
            Task {
                await refreshTask.value
                task.setTaskCompleted(success: !refreshTask.isCancelled)
            }
        }
    #endif

    // MARK: - macOS Background Support

    #if os(macOS)
        private var refreshTimer: Timer?

        /// Start periodic refresh timer for macOS
        @MainActor
        func startPeriodicRefresh() {
            stopPeriodicRefresh()

            let interval = refreshInterval
            guard interval > 0 else { return }

            let timerInterval = TimeInterval(interval * 60)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) {
                [weak self] _ in
                Task {
                    await self?.performBackgroundRefresh()
                }
            }

            print("[BackgroundRefresh] Started periodic refresh every \(interval) minutes")
        }

        /// Stop periodic refresh timer
        @MainActor
        func stopPeriodicRefresh() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    #endif

    // MARK: - Core Refresh Logic

    /// Perform background refresh of feeds
    /// Returns the number of new articles found
    @discardableResult
    func performBackgroundRefresh() async -> Int {
        // Check network conditions
        let shouldRefreshOnWiFiOnly = await MainActor.run { refreshOnWiFiOnly }

        guard isConnectedToNetwork else {
            print("[BackgroundRefresh] Skipped: No network connection")
            return 0
        }

        if shouldRefreshOnWiFiOnly && !isConnectedToWiFi {
            print("[BackgroundRefresh] Skipped: WiFi only mode and not on WiFi")
            return 0
        }

        print("[BackgroundRefresh] Starting refresh...")

        // Get feeds that need refreshing (prioritize by last update time)
        let feedsToRefresh = await getFeedsToRefresh()

        guard !feedsToRefresh.isEmpty else {
            print("[BackgroundRefresh] No feeds to refresh")
            return 0
        }

        var totalNewArticles = 0
        var newArticleInfos: [(id: String, title: String, feedId: String, feedTitle: String)] = []

        for feedInfo in feedsToRefresh {
            if Task.isCancelled { break }

            let (newCount, articles) = await refreshFeedWithArticleInfo(
                urlString: feedInfo.urlString)
            totalNewArticles += newCount
            newArticleInfos.append(contentsOf: articles)
        }

        // Send notifications for new articles
        if !newArticleInfos.isEmpty {
            await NotificationService.shared.sendNewArticleNotifications(articles: newArticleInfos)
        }

        print("[BackgroundRefresh] Completed. New articles: \(totalNewArticles)")

        return totalNewArticles
    }

    /// Get feeds that should be refreshed, sorted by priority
    /// Feeds that haven't been updated recently are prioritized
    @MainActor
    private func getFeedsToRefresh() async -> [FeedRefreshInfo] {
        guard let modelContainer = self.modelContainer else {
            print("[BackgroundRefresh] No model container available")
            return []
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Feed>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .forward)]
        )

        do {
            let feeds = try context.fetch(descriptor)
            let now = Date()

            // Filter feeds that haven't been updated in the minimum interval
            return feeds.compactMap { feed -> FeedRefreshInfo? in
                let timeSinceLastUpdate = now.timeIntervalSince(feed.lastUpdated ?? .distantPast)
                guard timeSinceLastUpdate >= Self.minimumRefreshInterval else {
                    return nil
                }
                return FeedRefreshInfo(urlString: feed.urlString, lastUpdated: feed.lastUpdated)
            }
        } catch {
            print("[BackgroundRefresh] Failed to fetch feeds: \(error)")
            return []
        }
    }

    /// Refresh a single feed by URL
    @MainActor
    private func refreshFeed(urlString: String) async -> Int {
        let (count, _) = await refreshFeedWithArticleInfo(urlString: urlString)
        return count
    }

    /// Refresh a single feed by URL and return new article info for notifications
    @MainActor
    private func refreshFeedWithArticleInfo(urlString: String) async -> (
        Int, [(id: String, title: String, feedId: String, feedTitle: String)]
    ) {
        guard let modelContainer = self.modelContainer else {
            return (0, [])
        }

        let context = modelContainer.mainContext
        let feedService = FeedService(modelContext: context)

        // Find the feed
        let predicate = #Predicate<Feed> { feed in
            feed.urlString == urlString
        }
        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            guard let feed = try context.fetch(descriptor).first else {
                return (0, [])
            }

            // Get existing article IDs before refresh
            let existingArticleIds = Set(feed.articles?.map { $0.id } ?? [])

            let newCount = try await feedService.refreshFeed(feed)

            // Get new article info for notifications
            var newArticleInfos: [(id: String, title: String, feedId: String, feedTitle: String)] =
                []

            if newCount > 0 {
                let newArticles =
                    feed.articles?.filter { !existingArticleIds.contains($0.id) } ?? []
                for article in newArticles {
                    newArticleInfos.append(
                        (
                            id: article.id.uuidString, title: article.title,
                            feedId: feed.id.uuidString,
                            feedTitle: feed.title
                        ))
                }
            }

            return (newCount, newArticleInfos)
        } catch {
            print("[BackgroundRefresh] Failed to refresh \(urlString): \(error)")
            return (0, [])
        }
    }
}

// MARK: - Supporting Types

/// Information about a feed for refresh priority calculation
private struct FeedRefreshInfo {
    let urlString: String
    let lastUpdated: Date?

    /// Priority score - higher means should be refreshed sooner
    var priority: TimeInterval {
        guard let lastUpdated = lastUpdated else {
            return .infinity  // Never updated, highest priority
        }
        return Date().timeIntervalSince(lastUpdated)
    }
}
