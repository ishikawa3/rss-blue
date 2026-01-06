import Foundation
import SwiftData

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
                feed.url.absoluteString == urlString
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
