import Testing
import Foundation
@testable import RSSBlue

@Suite("FeedParser Tests")
struct FeedParserTests {
    
    // MARK: - RSS 2.0 Parsing Tests
    
    @Test("Parse valid RSS 2.0 feed")
    func parseRSS2Feed() async throws {
        let rssXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Test RSS Feed</title>
                <link>https://example.com</link>
                <description>A test RSS feed</description>
                <item>
                    <title>First Article</title>
                    <link>https://example.com/article1</link>
                    <description>This is the first article</description>
                    <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
                    <guid>article-1</guid>
                </item>
                <item>
                    <title>Second Article</title>
                    <link>https://example.com/article2</link>
                    <description>This is the second article</description>
                    <pubDate>Tue, 02 Jan 2024 12:00:00 GMT</pubDate>
                    <guid>article-2</guid>
                </item>
            </channel>
        </rss>
        """
        
        let result = try parseXML(rssXML)
        
        #expect(result.title == "Test RSS Feed")
        #expect(result.description == "A test RSS feed")
        #expect(result.homePageURL?.absoluteString == "https://example.com")
        #expect(result.articles.count == 2)
        #expect(result.articles[0].title == "First Article")
        #expect(result.articles[0].id == "article-1")
        #expect(result.articles[1].title == "Second Article")
    }
    
    // MARK: - Atom 1.0 Parsing Tests
    
    @Test("Parse valid Atom 1.0 feed")
    func parseAtomFeed() async throws {
        let atomXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Test Atom Feed</title>
            <link href="https://example.com" rel="alternate"/>
            <subtitle>A test Atom feed</subtitle>
            <entry>
                <title>Atom Entry 1</title>
                <link href="https://example.com/entry1" rel="alternate"/>
                <id>entry-1</id>
                <summary>Summary of entry 1</summary>
                <published>2024-01-01T12:00:00Z</published>
                <author><name>Author Name</name></author>
            </entry>
        </feed>
        """
        
        let result = try parseXML(atomXML)
        
        #expect(result.title == "Test Atom Feed")
        #expect(result.description == "A test Atom feed")
        #expect(result.articles.count == 1)
        #expect(result.articles[0].title == "Atom Entry 1")
        #expect(result.articles[0].id == "entry-1")
        #expect(result.articles[0].author == "Author Name")
    }
    
    // MARK: - JSON Feed Parsing Tests
    
    @Test("Parse valid JSON Feed")
    func parseJSONFeed() async throws {
        let jsonFeed = """
        {
            "version": "https://jsonfeed.org/version/1.1",
            "title": "Test JSON Feed",
            "home_page_url": "https://example.com",
            "description": "A test JSON feed",
            "items": [
                {
                    "id": "json-item-1",
                    "title": "JSON Item 1",
                    "url": "https://example.com/item1",
                    "content_html": "<p>HTML content</p>",
                    "date_published": "2024-01-01T12:00:00Z"
                }
            ]
        }
        """
        
        let result = try parseJSON(jsonFeed)
        
        #expect(result.title == "Test JSON Feed")
        #expect(result.description == "A test JSON feed")
        #expect(result.articles.count == 1)
        #expect(result.articles[0].title == "JSON Item 1")
        #expect(result.articles[0].id == "json-item-1")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid XML gracefully")
    func handleInvalidXML() async throws {
        let invalidXML = "This is not valid XML <broken"
        
        do {
            _ = try parseXML(invalidXML)
            Issue.record("Expected parsing error for invalid XML")
        } catch {
            // Expected behavior
            #expect(error is FeedParserError)
        }
    }
    
    @Test("Handle empty feed")
    func handleEmptyFeed() async throws {
        let emptyRSS = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Empty Feed</title>
            </channel>
        </rss>
        """
        
        let result = try parseXML(emptyRSS)
        
        #expect(result.title == "Empty Feed")
        #expect(result.articles.isEmpty)
    }
    
    // MARK: - Article Property Tests
    
    @Test("Article URL parsing")
    func articleURLParsing() async throws {
        let rssXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>URL Test Feed</title>
                <item>
                    <title>Article with URL</title>
                    <link>https://example.com/article</link>
                </item>
            </channel>
        </rss>
        """
        
        let result = try parseXML(rssXML)
        
        #expect(result.articles[0].url?.absoluteString == "https://example.com/article")
    }
    
    @Test("Article date parsing")
    func articleDateParsing() async throws {
        let rssXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Date Test Feed</title>
                <item>
                    <title>Article with Date</title>
                    <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
                </item>
            </channel>
        </rss>
        """
        
        let result = try parseXML(rssXML)
        
        #expect(result.articles[0].publishedDate != nil)
    }
    
    // MARK: - Helper Methods
    
    private func parseXML(_ xml: String) throws -> ParsedFeed {
        guard let data = xml.data(using: .utf8) else {
            throw FeedParserError.parsingError("Failed to convert string to data")
        }
        
        let parser = FeedParser(data: data)
        let result = parser.parse()
        
        switch result {
        case .success(let feed):
            switch feed {
            case .rss(let rssFeed):
                return parsedFromRSS(rssFeed)
            case .atom(let atomFeed):
                return parsedFromAtom(atomFeed)
            case .json(let jsonFeed):
                return parsedFromJSON(jsonFeed)
            }
        case .failure(let error):
            throw FeedParserError.parsingError(error.localizedDescription)
        }
    }
    
    private func parseJSON(_ json: String) throws -> ParsedFeed {
        guard let data = json.data(using: .utf8) else {
            throw FeedParserError.parsingError("Failed to convert string to data")
        }
        
        let parser = FeedParser(data: data)
        let result = parser.parse()
        
        switch result {
        case .success(let feed):
            switch feed {
            case .json(let jsonFeed):
                return parsedFromJSON(jsonFeed)
            default:
                throw FeedParserError.unknownFeedType
            }
        case .failure(let error):
            throw FeedParserError.parsingError(error.localizedDescription)
        }
    }
    
    private func parsedFromRSS(_ feed: RSSFeed) -> ParsedFeed {
        let articles = (feed.items ?? []).compactMap { item -> ParsedArticle? in
            guard let title = item.title else { return nil }
            return ParsedArticle(
                id: item.guid?.value ?? item.link ?? UUID().uuidString,
                title: title,
                summary: item.description,
                contentHTML: item.content?.contentEncoded ?? item.description,
                url: item.link.flatMap { URL(string: $0) },
                author: item.author,
                publishedDate: item.pubDate
            )
        }
        
        return ParsedFeed(
            title: feed.title ?? "Unknown",
            description: feed.description,
            homePageURL: feed.link.flatMap { URL(string: $0) },
            imageURL: nil,
            articles: articles
        )
    }
    
    private func parsedFromAtom(_ feed: AtomFeed) -> ParsedFeed {
        let articles = (feed.entries ?? []).compactMap { entry -> ParsedArticle? in
            guard let title = entry.title else { return nil }
            let link = entry.links?.first?.attributes?.href
            return ParsedArticle(
                id: entry.id ?? UUID().uuidString,
                title: title,
                summary: entry.summary?.value,
                contentHTML: entry.content?.value,
                url: link.flatMap { URL(string: $0) },
                author: entry.authors?.first?.name,
                publishedDate: entry.published ?? entry.updated
            )
        }
        
        let homePageLink = feed.links?.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href
        
        return ParsedFeed(
            title: feed.title ?? "Unknown",
            description: feed.subtitle?.value,
            homePageURL: homePageLink.flatMap { URL(string: $0) },
            imageURL: nil,
            articles: articles
        )
    }
    
    private func parsedFromJSON(_ feed: JSONFeed) -> ParsedFeed {
        let articles = (feed.items ?? []).compactMap { item -> ParsedArticle? in
            guard let title = item.title else { return nil }
            return ParsedArticle(
                id: item.id ?? UUID().uuidString,
                title: title,
                summary: item.summary,
                contentHTML: item.contentHtml,
                url: item.url.flatMap { URL(string: $0) },
                author: item.author?.name,
                publishedDate: item.datePublished
            )
        }
        
        return ParsedFeed(
            title: feed.title ?? "Unknown",
            description: feed.description,
            homePageURL: feed.homePageURL.flatMap { URL(string: $0) },
            imageURL: nil,
            articles: articles
        )
    }
}

// Import FeedKit for test helper methods
import FeedKit
