import Foundation
import SwiftData
import WidgetKit

/// Service for managing feed operations
@MainActor
final class FeedService: ObservableObject {
    private let modelContext: ModelContext
    private let parserService: FeedParserService

    @Published var isLoading = false
    @Published var error: FeedServiceError?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.parserService = FeedParserService()
    }

    // MARK: - Add Feed

    /// Adds a new feed from the given URL
    /// - Parameter urlString: The URL string of the feed
    /// - Returns: The created Feed object
    /// - Throws: FeedServiceError if the operation fails
    func addFeed(from urlString: String) async throws -> Feed {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Validate URL format
        guard let url = validateAndNormalizeURL(urlString) else {
            let err = FeedServiceError.invalidURL
            error = err
            throw err
        }

        // Check for duplicates
        if try await feedExists(url: url) {
            let err = FeedServiceError.duplicateFeed
            error = err
            throw err
        }

        // Fetch and parse the feed
        let parseResult: ParsedFeed
        do {
            parseResult = try await parserService.fetchAndParse(url: url)
        } catch let parserError as FeedParserError {
            let err = FeedServiceError.parsingFailed(parserError.localizedDescription)
            self.error = err
            throw err
        } catch {
            let err = FeedServiceError.networkError(error.localizedDescription)
            self.error = err
            throw err
        }

        // Create and save the feed
        let feed = Feed(title: parseResult.title, url: url)
        feed.feedDescription = parseResult.description
        feed.homePageURL = parseResult.homePageURL
        feed.lastUpdated = Date()

        modelContext.insert(feed)

        // Create articles
        for articleData in parseResult.articles {
            let article = Article(title: articleData.title, feed: feed)
            article.url = articleData.url
            article.summary = articleData.summary
            article.contentHTML = articleData.contentHTML
            article.author = articleData.author
            article.publishedDate = articleData.publishedDate
            article.id = UUID(uuidString: articleData.id) ?? UUID()

            modelContext.insert(article)
        }

        try modelContext.save()

        return feed
    }

    // MARK: - Delete Feed

    /// Deletes a feed and all its articles
    /// - Parameter feed: The feed to delete
    func deleteFeed(_ feed: Feed) throws {
        modelContext.delete(feed)
        try modelContext.save()
    }

    // MARK: - Validation

    /// Validates and normalizes a URL string
    /// - Parameter urlString: The URL string to validate
    /// - Returns: A valid URL or nil if invalid
    func validateAndNormalizeURL(_ urlString: String) -> URL? {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https:// if no scheme is provided
        if !normalized.lowercased().hasPrefix("http://")
            && !normalized.lowercased().hasPrefix("https://")
        {
            normalized = "https://" + normalized
        }

        guard let url = URL(string: normalized),
            let host = url.host,
            !host.isEmpty
        else {
            return nil
        }

        return url
    }

    /// Checks if a feed with the given URL already exists
    /// - Parameter url: The URL to check
    /// - Returns: True if a feed with this URL exists
    func feedExists(url: URL) async throws -> Bool {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<Feed>(
            predicate: #Predicate<Feed> { feed in
                feed.urlString == urlString
            }
        )

        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }

    /// Validates a feed URL without adding it
    /// - Parameter urlString: The URL string to validate
    /// - Returns: The parsed feed result if valid
    func validateFeed(urlString: String) async throws -> ParsedFeed {
        guard let url = validateAndNormalizeURL(urlString) else {
            throw FeedServiceError.invalidURL
        }

        return try await parserService.fetchAndParse(url: url)
    }

    // MARK: - Refresh Feeds

    /// Refreshes all feeds and returns the count of new articles
    /// - Returns: The total number of new articles added
    func refreshAllFeeds() async throws -> Int {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let descriptor = FetchDescriptor<Feed>()
        let feeds = try modelContext.fetch(descriptor)

        var totalNewArticles = 0
        var lastError: FeedServiceError?

        for feed in feeds {
            do {
                let newCount = try await refreshFeed(feed)
                totalNewArticles += newCount
            } catch let err as FeedServiceError {
                lastError = err
                // Continue refreshing other feeds even if one fails
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        // If all feeds failed, throw the last error
        if totalNewArticles == 0, let err = lastError {
            self.error = err
            throw err
        }

        // Update widget data
        updateWidgetData()

        return totalNewArticles
    }

    /// Updates widget data with current unread articles
    private func updateWidgetData() {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { !$0.isRead },
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )

        do {
            let unreadArticles = try modelContext.fetch(descriptor)
            let recentArticles = unreadArticles.prefix(20).map { article in
                WidgetArticle(
                    id: article.id.uuidString,
                    title: article.title,
                    feedTitle: article.feed?.title ?? "Unknown",
                    publishedDate: article.publishedDate,
                    isRead: article.isRead
                )
            }

            let widgetData = WidgetData(
                unreadCount: unreadArticles.count,
                recentArticles: Array(recentArticles),
                lastUpdated: Date()
            )

            WidgetDataManager.shared.saveWidgetData(widgetData)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[FeedService] Failed to update widget data: \(error)")
        }
    }

    /// Refreshes a single feed and returns the count of new articles
    /// - Parameter feed: The feed to refresh
    /// - Returns: The number of new articles added
    @discardableResult
    func refreshFeed(_ feed: Feed) async throws -> Int {
        let parseResult: ParsedFeed
        do {
            parseResult = try await parserService.fetchAndParse(url: feed.url)
        } catch let parserError as FeedParserError {
            throw FeedServiceError.parsingFailed(parserError.localizedDescription)
        } catch {
            throw FeedServiceError.networkError(error.localizedDescription)
        }

        // Update feed metadata
        feed.title = parseResult.title
        feed.feedDescription = parseResult.description
        feed.homePageURL = parseResult.homePageURL
        feed.lastUpdated = Date()

        // Get existing article IDs
        let existingIds = Set(
            (feed.articles ?? []).compactMap { article -> String? in
                // Use URL as unique identifier since that's more reliable
                article.url?.absoluteString
            })

        var newArticleCount = 0

        // Add only new articles
        for articleData in parseResult.articles {
            let articleId = articleData.url?.absoluteString ?? articleData.id

            if !existingIds.contains(articleId) {
                let article = Article(title: articleData.title, feed: feed)
                article.url = articleData.url
                article.summary = articleData.summary
                article.contentHTML = articleData.contentHTML
                article.author = articleData.author
                article.publishedDate = articleData.publishedDate
                article.id = UUID(uuidString: articleData.id) ?? UUID()

                modelContext.insert(article)
                newArticleCount += 1
            }
        }

        try modelContext.save()

        return newArticleCount
    }

    // MARK: - Full Content Extraction

    private let contentExtractor = ContentExtractorService()

    /// Fetches full content for an article
    /// - Parameter article: The article to fetch content for
    /// - Returns: True if content was successfully extracted
    @discardableResult
    func fetchFullContent(for article: Article) async throws -> Bool {
        guard let url = article.url else {
            return false
        }

        // Skip if already fetched
        if article.hasFullContent {
            return true
        }

        do {
            let extracted = try await contentExtractor.extractContent(from: url)
            article.fullContent = extracted.content
            article.hasFullContent = true

            // Update author if not set and extracted
            if article.author == nil, let author = extracted.author {
                article.author = author
            }

            try modelContext.save()
            return true
        } catch {
            // Log error but don't throw - full content is optional
            print("[FeedService] Failed to fetch full content for \(url): \(error)")
            return false
        }
    }

    /// Fetches full content for all articles in a feed that haven't been fetched yet
    /// - Parameter feed: The feed to fetch content for
    /// - Returns: The number of articles successfully fetched
    func fetchFullContentForFeed(_ feed: Feed) async -> Int {
        guard feed.fetchFullContent else { return 0 }

        var successCount = 0
        let articles = (feed.articles ?? []).filter { !$0.hasFullContent && $0.url != nil }

        for article in articles {
            do {
                if try await fetchFullContent(for: article) {
                    successCount += 1
                }
            } catch {
                // Continue with other articles
            }

            // Small delay to avoid overwhelming servers
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        return successCount
    }

    // MARK: - OPML Import/Export

    /// Result of an OPML import operation
    struct OPMLImportResult {
        let imported: Int
        let skipped: Int
        let failed: Int
        let errors: [String]
    }

    /// Imports feeds from OPML data
    /// - Parameters:
    ///   - data: The OPML file data
    ///   - skipDuplicates: Whether to skip duplicate feeds (default: true)
    /// - Returns: The import result
    func importOPML(data: Data, skipDuplicates: Bool = true) async throws -> OPMLImportResult {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let opmlService = OPMLService()
        let document = try opmlService.parse(data: data)
        let feeds = document.allFeeds

        if feeds.isEmpty {
            throw OPMLError.noFeeds
        }

        var imported = 0
        var skipped = 0
        var failed = 0
        var errors: [String] = []

        for outline in feeds {
            guard let feedURL = outline.feedURL else { continue }

            do {
                // Check for duplicates
                if skipDuplicates {
                    let exists = try await feedExists(url: feedURL)
                    if exists {
                        skipped += 1
                        continue
                    }
                }

                // Try to add the feed
                _ = try await addFeed(from: feedURL.absoluteString)
                imported += 1
            } catch {
                failed += 1
                errors.append("\(outline.title): \(error.localizedDescription)")
            }
        }

        return OPMLImportResult(
            imported: imported, skipped: skipped, failed: failed, errors: errors)
    }

    /// Imports feeds from an OPML file URL
    /// - Parameter url: The file URL
    /// - Returns: The import result
    func importOPML(fileURL: URL) async throws -> OPMLImportResult {
        let data = try Data(contentsOf: fileURL)
        return try await importOPML(data: data)
    }

    /// Exports all feeds to OPML data
    /// - Parameter title: The title for the OPML document
    /// - Returns: The OPML data
    func exportOPML(title: String = "RSS Blue Subscriptions") throws -> Data {
        let descriptor = FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.title)])
        let feeds = try modelContext.fetch(descriptor)

        let opmlService = OPMLService()
        return try opmlService.generate(feeds: feeds, title: title)
    }
}

// MARK: - Errors

enum FeedServiceError: LocalizedError {
    case invalidURL
    case duplicateFeed
    case parsingFailed(String)
    case networkError(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .duplicateFeed:
            return "This feed has already been added"
        case .parsingFailed(let reason):
            return "Failed to parse feed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid feed URL (e.g., https://example.com/feed.xml)"
        case .duplicateFeed:
            return "This feed is already in your library"
        case .parsingFailed:
            return "Make sure the URL points to a valid RSS, Atom, or JSON feed"
        case .networkError:
            return "Check your internet connection and try again"
        case .saveFailed:
            return "Try again later"
        }
    }
}
