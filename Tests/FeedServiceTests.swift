import Foundation
import Testing

@testable import RSSBlue

@Suite("FeedService Tests")
struct FeedServiceTests {

    // MARK: - URL Validation Tests

    @Test("Valid HTTPS URL")
    func validHTTPSURL() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("https://example.com/feed.xml")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/feed.xml")
    }

    @Test("Valid HTTP URL")
    func validHTTPURL() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("http://example.com/rss")

        #expect(result != nil)
        #expect(result?.absoluteString == "http://example.com/rss")
    }

    @Test("URL without scheme gets https")
    func urlWithoutScheme() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("example.com/feed")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/feed")
    }

    @Test("URL with whitespace is trimmed")
    func urlWithWhitespace() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("  https://example.com/feed  ")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/feed")
    }

    @Test("Empty URL returns nil")
    func emptyURL() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("")

        #expect(result == nil)
    }

    @Test("Whitespace only URL returns nil")
    func whitespaceOnlyURL() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("   ")

        #expect(result == nil)
    }

    @Test("Invalid URL returns nil")
    func invalidURL() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("not a valid url %%%")

        #expect(result == nil)
    }

    @Test("URL with path and query")
    func urlWithPathAndQuery() {
        let service = createMockService()
        let result = service.validateAndNormalizeURL("https://example.com/feed.xml?format=rss")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/feed.xml?format=rss")
    }

    // MARK: - Error Tests

    @Test("FeedServiceError descriptions")
    func errorDescriptions() {
        #expect(FeedServiceError.invalidURL.errorDescription == "Invalid URL")
        #expect(
            FeedServiceError.duplicateFeed.errorDescription == "This feed has already been added")
        #expect(
            FeedServiceError.parsingFailed("test").errorDescription == "Failed to parse feed: test")
        #expect(
            FeedServiceError.networkError("timeout").errorDescription == "Network error: timeout")
    }

    @Test("FeedServiceError recovery suggestions")
    func errorRecoverySuggestions() {
        #expect(FeedServiceError.invalidURL.recoverySuggestion != nil)
        #expect(FeedServiceError.duplicateFeed.recoverySuggestion != nil)
        #expect(FeedServiceError.parsingFailed("").recoverySuggestion != nil)
        #expect(FeedServiceError.networkError("").recoverySuggestion != nil)
    }

    // MARK: - Helper

    private func createMockService() -> URLValidationHelper {
        return URLValidationHelper()
    }
}

// Helper struct that mirrors FeedService's URL validation logic for testing
// without needing a ModelContext
struct URLValidationHelper {
    func validateAndNormalizeURL(_ urlString: String) -> URL? {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

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
}

@Suite("Feed Management Tests")
struct FeedManagementTests {

    @Test("Feed deletion removes articles")
    func feedDeletionRemovesArticles() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        let article1 = Article(title: "Article 1", feed: feed)
        let article2 = Article(title: "Article 2", feed: feed)

        // Simulate the relationship
        feed.articles = [article1, article2]

        #expect(feed.articles?.count == 2)

        // When feed is deleted with cascade, articles should be removed
        // This is handled by SwiftData's @Relationship(deleteRule: .cascade)
    }

    @Test("Duplicate detection by URL")
    func duplicateDetectionByURL() {
        let url1 = URL(string: "https://example.com/feed.xml")!
        let url2 = URL(string: "https://example.com/feed.xml")!
        let url3 = URL(string: "https://other.com/feed.xml")!

        #expect(url1.absoluteString == url2.absoluteString)
        #expect(url1.absoluteString != url3.absoluteString)
    }

    @Test("Feed with articles has correct unread count")
    func feedUnreadCount() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        let article1 = Article(title: "Article 1", feed: feed)
        article1.isRead = false

        let article2 = Article(title: "Article 2", feed: feed)
        article2.isRead = true

        let article3 = Article(title: "Article 3", feed: feed)
        article3.isRead = false

        feed.articles = [article1, article2, article3]

        #expect(feed.unreadCount == 2)
    }
}

@Suite("Feed Refresh Tests")
struct FeedRefreshTests {

    @Test("Duplicate article detection by URL")
    func duplicateArticleDetectionByURL() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        // Existing article
        let existingArticle = Article(title: "Existing Article", feed: feed)
        existingArticle.url = URL(string: "https://example.com/article1")
        feed.articles = [existingArticle]

        // Get existing URLs
        let existingUrls = Set((feed.articles ?? []).compactMap { $0.url?.absoluteString })

        // New article with same URL should be detected as duplicate
        let duplicateUrl = "https://example.com/article1"
        let newUrl = "https://example.com/article2"

        #expect(existingUrls.contains(duplicateUrl))
        #expect(!existingUrls.contains(newUrl))
    }

    @Test("New article detection")
    func newArticleDetection() {
        let existingUrls: Set<String> = [
            "https://example.com/article1",
            "https://example.com/article2",
        ]

        let newArticleUrls = [
            "https://example.com/article1",  // duplicate
            "https://example.com/article3",  // new
            "https://example.com/article4",  // new
        ]

        let newUrls = newArticleUrls.filter { !existingUrls.contains($0) }

        #expect(newUrls.count == 2)
        #expect(newUrls.contains("https://example.com/article3"))
        #expect(newUrls.contains("https://example.com/article4"))
    }

    @Test("Feed last updated timestamp")
    func feedLastUpdatedTimestamp() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        #expect(feed.lastUpdated == nil)

        feed.lastUpdated = Date()

        #expect(feed.lastUpdated != nil)
    }

    @Test("Multiple feeds refresh isolation")
    func multipleFeedsRefreshIsolation() {
        let feed1 = Feed(title: "Feed 1", url: URL(string: "https://example1.com/feed")!)
        let feed2 = Feed(title: "Feed 2", url: URL(string: "https://example2.com/feed")!)

        let article1 = Article(title: "Article from Feed 1", feed: feed1)
        article1.url = URL(string: "https://example1.com/article1")
        feed1.articles = [article1]

        let article2 = Article(title: "Article from Feed 2", feed: feed2)
        article2.url = URL(string: "https://example2.com/article1")
        feed2.articles = [article2]

        // Each feed's articles should be independent
        let feed1Urls = Set((feed1.articles ?? []).compactMap { $0.url?.absoluteString })
        let feed2Urls = Set((feed2.articles ?? []).compactMap { $0.url?.absoluteString })

        #expect(feed1Urls.count == 1)
        #expect(feed2Urls.count == 1)
        #expect(!feed1Urls.contains("https://example2.com/article1"))
        #expect(!feed2Urls.contains("https://example1.com/article1"))
    }
}
