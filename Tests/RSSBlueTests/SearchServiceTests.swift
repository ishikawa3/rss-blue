import Foundation
import Testing

@testable import RSSBlue

@Suite("SearchService Tests")
struct SearchServiceTests {
    // MARK: - matches tests

    @Test("Empty query matches all articles")
    func emptyQueryMatchesAll() {
        let article = createTestArticle(
            title: "Test Title",
            summary: "Test summary",
            contentHTML: "<p>Test content</p>"
        )

        #expect(SearchService.matches(article: article, query: ""))
    }

    @Test("Matches article by title")
    func matchesByTitle() {
        let article = createTestArticle(
            title: "Swift Programming Guide",
            summary: nil,
            contentHTML: nil
        )

        #expect(SearchService.matches(article: article, query: "Swift"))
        #expect(SearchService.matches(article: article, query: "swift"))  // case insensitive
        #expect(SearchService.matches(article: article, query: "PROGRAMMING"))
        #expect(!SearchService.matches(article: article, query: "Python"))
    }

    @Test("Matches article by summary")
    func matchesBySummary() {
        let article = createTestArticle(
            title: "Title",
            summary: "This is a comprehensive guide to iOS development",
            contentHTML: nil
        )

        #expect(SearchService.matches(article: article, query: "iOS"))
        #expect(SearchService.matches(article: article, query: "comprehensive"))
        #expect(!SearchService.matches(article: article, query: "Android"))
    }

    @Test("Matches article by content HTML with tags stripped")
    func matchesByContentHTML() {
        let article = createTestArticle(
            title: "Title",
            summary: nil,
            contentHTML: "<p>Learn about <strong>SwiftUI</strong> and <em>Combine</em></p>"
        )

        #expect(SearchService.matches(article: article, query: "SwiftUI"))
        #expect(SearchService.matches(article: article, query: "Combine"))
        #expect(SearchService.matches(article: article, query: "Learn"))
        #expect(!SearchService.matches(article: article, query: "<p>"))  // tags should be stripped
    }

    @Test("Matches article by author name")
    func matchesByAuthor() {
        let article = createTestArticle(
            title: "Title",
            summary: nil,
            contentHTML: nil,
            author: "John Appleseed"
        )

        #expect(SearchService.matches(article: article, query: "John"))
        #expect(SearchService.matches(article: article, query: "Appleseed"))
        #expect(!SearchService.matches(article: article, query: "Jane"))
    }

    // MARK: - stripHTMLTags tests

    @Test("Strips HTML tags correctly")
    func stripHTMLTags() {
        let html = "<p>Hello <strong>World</strong>!</p>"
        let result = SearchService.stripHTMLTags(from: html)
        #expect(result == "Hello World!")
    }

    @Test("Handles nested HTML tags")
    func stripNestedHTMLTags() {
        let html = "<div><p>Outer <span>Inner <a href='#'>Link</a></span></p></div>"
        let result = SearchService.stripHTMLTags(from: html)
        #expect(result == "Outer Inner Link")
    }

    @Test("Returns same string when no HTML tags")
    func noHTMLTags() {
        let text = "Plain text without tags"
        let result = SearchService.stripHTMLTags(from: text)
        #expect(result == text)
    }

    @Test("Collapses whitespace")
    func collapsesWhitespace() {
        let html = "<p>Multiple   spaces</p>\n\n<p>And newlines</p>"
        let result = SearchService.stripHTMLTags(from: html)
        #expect(result == "Multiple spaces And newlines")
    }

    // MARK: - extractSnippet tests

    @Test("Extracts snippet around query")
    func extractSnippetAroundQuery() {
        let text = "This is a long text that contains the word Swift somewhere in the middle."
        let snippet = SearchService.extractSnippet(from: text, around: "Swift", contextLength: 10)

        #expect(snippet.contains("Swift"))
        #expect(snippet.contains("..."))
    }

    @Test("Full text returned when short enough")
    func shortTextSnippet() {
        let text = "Short Swift text"
        let snippet = SearchService.extractSnippet(from: text, around: "Swift", contextLength: 50)

        #expect(snippet == text)
    }

    @Test("Returns prefix when query not found")
    func queryNotFoundSnippet() {
        let text =
            "This is a text that doesn't contain the search term anywhere in its content at all."
        let snippet = SearchService.extractSnippet(from: text, around: "xyz", contextLength: 10)

        #expect(snippet.count <= 100)
    }

    // MARK: - findMatchRanges tests

    @Test("Finds single match range")
    func findSingleMatchRange() {
        let text = "Hello Swift World"
        let ranges = SearchService.findMatchRanges(in: text, for: "Swift")

        #expect(ranges.count == 1)
        #expect(String(text[ranges[0]]) == "Swift")
    }

    @Test("Finds multiple match ranges")
    func findMultipleMatchRanges() {
        let text = "Swift is great. I love Swift programming in Swift."
        let ranges = SearchService.findMatchRanges(in: text, for: "Swift")

        #expect(ranges.count == 3)
    }

    @Test("Case insensitive match ranges")
    func caseInsensitiveMatchRanges() {
        let text = "SWIFT swift SwIfT"
        let ranges = SearchService.findMatchRanges(in: text, for: "swift")

        #expect(ranges.count == 3)
    }

    @Test("Empty query returns no ranges")
    func emptyQueryNoRanges() {
        let text = "Some text"
        let ranges = SearchService.findMatchRanges(in: text, for: "")

        #expect(ranges.isEmpty)
    }

    @Test("No match returns empty ranges")
    func noMatchReturnsEmpty() {
        let text = "Some text without match"
        let ranges = SearchService.findMatchRanges(in: text, for: "xyz")

        #expect(ranges.isEmpty)
    }

    // MARK: - findMatchSnippet tests

    @Test("Finds match snippet in title")
    func findMatchSnippetInTitle() {
        let article = createTestArticle(
            title: "Swift Programming Guide",
            summary: "Other content",
            contentHTML: nil
        )

        let snippet = SearchService.findMatchSnippet(in: article, for: "Swift")
        #expect(snippet == "Swift Programming Guide")
    }

    @Test("Finds match snippet in summary")
    func findMatchSnippetInSummary() {
        let article = createTestArticle(
            title: "Title",
            summary: "This guide covers advanced Swift topics for iOS development.",
            contentHTML: nil
        )

        let snippet = SearchService.findMatchSnippet(in: article, for: "Swift")
        #expect(snippet != nil)
        #expect(snippet?.contains("Swift") == true)
    }

    @Test("Finds match snippet in contentHTML")
    func findMatchSnippetInContent() {
        let article = createTestArticle(
            title: "Title",
            summary: nil,
            contentHTML:
                "<p>Introduction</p><p>This section explains SwiftUI basics in detail.</p>"
        )

        let snippet = SearchService.findMatchSnippet(in: article, for: "SwiftUI")
        #expect(snippet != nil)
        #expect(snippet?.contains("SwiftUI") == true)
    }

    @Test("Returns nil for empty query")
    func noSnippetForEmptyQuery() {
        let article = createTestArticle(
            title: "Title",
            summary: "Summary",
            contentHTML: nil
        )

        let snippet = SearchService.findMatchSnippet(in: article, for: "")
        #expect(snippet == nil)
    }

    // MARK: - Helper

    private func createTestArticle(
        title: String,
        summary: String?,
        contentHTML: String?,
        author: String? = nil
    ) -> Article {
        let article = Article(title: title)
        article.summary = summary
        article.contentHTML = contentHTML
        article.author = author
        article.url = URL(string: "https://example.com/article")
        article.publishedDate = Date()
        return article
    }
}
