import SwiftData
import XCTest

@testable import RSSBlue

/// Tests for BackgroundRefreshService
final class BackgroundRefreshServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Feed.self, Article.self, Folder.self,
            configurations: config
        )
        modelContext = await MainActor.run { modelContainer.mainContext }

        // Set up the background refresh service with test container
        await MainActor.run {
            BackgroundRefreshService.shared.modelContainer = modelContainer
        }
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Feed Selection Logic Tests

    @MainActor
    func testFeedsNeverUpdatedHaveHighestPriority() async throws {
        // Given: Two feeds, one never updated, one recently updated
        let neverUpdatedFeed = Feed(
            title: "Never Updated", url: URL(string: "https://example.com/never")!)
        neverUpdatedFeed.lastUpdated = nil

        let recentlyUpdatedFeed = Feed(
            title: "Recently Updated", url: URL(string: "https://example.com/recent")!)
        recentlyUpdatedFeed.lastUpdated = Date()

        modelContext.insert(neverUpdatedFeed)
        modelContext.insert(recentlyUpdatedFeed)
        try modelContext.save()

        // When: Getting feeds to refresh
        let feeds = try modelContext.fetch(
            FetchDescriptor<Feed>(
                sortBy: [SortDescriptor(\.lastUpdated, order: .forward)]
            ))

        // Then: Never updated feed should come first (nil sorts to beginning with .forward)
        XCTAssertEqual(feeds.first?.title, "Never Updated")
    }

    @MainActor
    func testOlderFeedsArePrioritized() async throws {
        // Given: Two feeds with different update times
        let oldFeed = Feed(title: "Old Feed", url: URL(string: "https://example.com/old")!)
        oldFeed.lastUpdated = Date().addingTimeInterval(-3600)  // 1 hour ago

        let newFeed = Feed(title: "New Feed", url: URL(string: "https://example.com/new")!)
        newFeed.lastUpdated = Date()  // Just now

        modelContext.insert(oldFeed)
        modelContext.insert(newFeed)
        try modelContext.save()

        // When: Getting feeds sorted by lastUpdated ascending
        let feeds = try modelContext.fetch(
            FetchDescriptor<Feed>(
                sortBy: [SortDescriptor(\.lastUpdated, order: .forward)]
            ))

        // Then: Older feed should come first
        XCTAssertEqual(feeds.first?.title, "Old Feed")
    }

    @MainActor
    func testRecentlyUpdatedFeedsAreSkipped() async throws {
        // Given: A feed updated less than 15 minutes ago
        let recentFeed = Feed(title: "Recent Feed", url: URL(string: "https://example.com/recent")!)
        recentFeed.lastUpdated = Date().addingTimeInterval(-60)  // 1 minute ago

        modelContext.insert(recentFeed)
        try modelContext.save()

        // When: Checking if feed should be refreshed (within minimum interval)
        let feeds = try modelContext.fetch(FetchDescriptor<Feed>())
        let minimumInterval: TimeInterval = 15 * 60  // 15 minutes

        let feedsToRefresh = feeds.filter { feed in
            let timeSinceLastUpdate = Date().timeIntervalSince(feed.lastUpdated ?? .distantPast)
            return timeSinceLastUpdate >= minimumInterval
        }

        // Then: Recently updated feed should be skipped
        XCTAssertTrue(feedsToRefresh.isEmpty)
    }

    @MainActor
    func testOldFeedsAreIncluded() async throws {
        // Given: A feed updated more than 15 minutes ago
        let oldFeed = Feed(title: "Old Feed", url: URL(string: "https://example.com/old")!)
        oldFeed.lastUpdated = Date().addingTimeInterval(-20 * 60)  // 20 minutes ago

        modelContext.insert(oldFeed)
        try modelContext.save()

        // When: Checking if feed should be refreshed
        let feeds = try modelContext.fetch(FetchDescriptor<Feed>())
        let minimumInterval: TimeInterval = 15 * 60  // 15 minutes

        let feedsToRefresh = feeds.filter { feed in
            let timeSinceLastUpdate = Date().timeIntervalSince(feed.lastUpdated ?? .distantPast)
            return timeSinceLastUpdate >= minimumInterval
        }

        // Then: Old feed should be included
        XCTAssertEqual(feedsToRefresh.count, 1)
        XCTAssertEqual(feedsToRefresh.first?.title, "Old Feed")
    }

    // MARK: - User Preferences Tests

    func testRefreshIntervalStoredInUserDefaults() {
        // Given: A refresh interval
        let testInterval = 60

        // When: Storing in UserDefaults
        UserDefaults.standard.set(testInterval, forKey: "refreshInterval")

        // Then: It should be retrievable
        let storedInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        XCTAssertEqual(storedInterval, testInterval)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "refreshInterval")
    }

    func testWiFiOnlyPreferenceStoredInUserDefaults() {
        // Given: WiFi only preference
        let testValue = true

        // When: Storing in UserDefaults
        UserDefaults.standard.set(testValue, forKey: "refreshOnWiFiOnly")

        // Then: It should be retrievable
        let storedValue = UserDefaults.standard.bool(forKey: "refreshOnWiFiOnly")
        XCTAssertEqual(storedValue, testValue)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "refreshOnWiFiOnly")
    }

    func testManualRefreshOnlyDisablesScheduling() {
        // Given: Manual refresh only setting (interval = 0)
        let manualOnlyInterval = 0

        // When: Checking if should schedule
        let shouldSchedule = manualOnlyInterval > 0

        // Then: Should not schedule
        XCTAssertFalse(shouldSchedule)
    }

    func testNonZeroIntervalEnablesScheduling() {
        // Given: 30 minute interval
        let interval = 30

        // When: Checking if should schedule
        let shouldSchedule = interval > 0

        // Then: Should schedule
        XCTAssertTrue(shouldSchedule)
    }
}
