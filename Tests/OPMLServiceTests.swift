import Foundation
import Testing

@testable import RSSBlue

@Suite("OPML Service Tests")
struct OPMLServiceTests {
    let opmlService = OPMLService()

    // MARK: - Sample OPML Data

    let validOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>My Subscriptions</title>
                <dateCreated>2024-01-01T00:00:00Z</dateCreated>
            </head>
            <body>
                <outline type="rss" text="TechCrunch" title="TechCrunch" xmlUrl="https://techcrunch.com/feed/" htmlUrl="https://techcrunch.com"/>
                <outline type="rss" text="The Verge" title="The Verge" xmlUrl="https://www.theverge.com/rss/index.xml" htmlUrl="https://www.theverge.com"/>
            </body>
        </opml>
        """

    let opmlWithFolders = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>Organized Feeds</title>
            </head>
            <body>
                <outline text="Tech">
                    <outline type="rss" text="TechCrunch" xmlUrl="https://techcrunch.com/feed/"/>
                    <outline type="rss" text="Ars Technica" xmlUrl="https://feeds.arstechnica.com/arstechnica/features"/>
                </outline>
                <outline text="News">
                    <outline type="rss" text="BBC News" xmlUrl="https://feeds.bbci.co.uk/news/rss.xml"/>
                </outline>
                <outline type="rss" text="Uncategorized Feed" xmlUrl="https://example.com/feed.xml"/>
            </body>
        </opml>
        """

    let emptyOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>Empty</title>
            </head>
            <body>
            </body>
        </opml>
        """

    let invalidXML = """
        This is not valid XML at all
        """

    // MARK: - Parsing Tests

    @Test("Parse valid OPML with feeds")
    func parseValidOPML() throws {
        let data = validOPML.data(using: .utf8)!
        let document = try opmlService.parse(data: data)

        #expect(document.title == "My Subscriptions")
        #expect(document.allFeeds.count == 2)

        let feeds = document.allFeeds
        #expect(feeds[0].title == "TechCrunch")
        #expect(feeds[0].feedURL?.absoluteString == "https://techcrunch.com/feed/")
        #expect(feeds[0].htmlURL?.absoluteString == "https://techcrunch.com")

        #expect(feeds[1].title == "The Verge")
        #expect(feeds[1].feedURL?.absoluteString == "https://www.theverge.com/rss/index.xml")
    }

    @Test("Parse OPML with folders - extracts all feeds")
    func parseOPMLWithFolders() throws {
        let data = opmlWithFolders.data(using: .utf8)!
        let document = try opmlService.parse(data: data)

        #expect(document.title == "Organized Feeds")

        let feeds = document.allFeeds
        #expect(feeds.count == 4)

        let urls = feeds.compactMap { $0.feedURL?.absoluteString }
        #expect(urls.contains("https://techcrunch.com/feed/"))
        #expect(urls.contains("https://feeds.arstechnica.com/arstechnica/features"))
        #expect(urls.contains("https://feeds.bbci.co.uk/news/rss.xml"))
        #expect(urls.contains("https://example.com/feed.xml"))
    }

    @Test("Parse empty OPML returns no feeds")
    func parseEmptyOPML() throws {
        let data = emptyOPML.data(using: .utf8)!
        let document = try opmlService.parse(data: data)

        #expect(document.title == "Empty")
        #expect(document.allFeeds.isEmpty)
    }

    @Test("Parse invalid XML throws error")
    func parseInvalidXML() {
        let data = invalidXML.data(using: .utf8)!

        #expect(throws: OPMLError.self) {
            _ = try opmlService.parse(data: data)
        }
    }

    // MARK: - Generation Tests

    @Test("Generate OPML from feeds")
    func generateOPML() throws {
        // Create mock feeds
        let feed1 = Feed(title: "Test Feed 1", url: URL(string: "https://example.com/feed1.xml")!)
        feed1.homePageURL = URL(string: "https://example.com")

        let feed2 = Feed(title: "Test Feed 2", url: URL(string: "https://example.org/feed.rss")!)

        let data = try opmlService.generate(feeds: [feed1, feed2], title: "My Export")
        let xmlString = String(data: data, encoding: .utf8)!

        #expect(xmlString.contains("<title>My Export</title>"))
        #expect(xmlString.contains("xmlUrl=\"https://example.com/feed1.xml\""))
        #expect(xmlString.contains("htmlUrl=\"https://example.com\""))
        #expect(xmlString.contains("title=\"Test Feed 1\""))
        #expect(xmlString.contains("xmlUrl=\"https://example.org/feed.rss\""))
        #expect(xmlString.contains("title=\"Test Feed 2\""))
    }

    @Test("Generate and parse roundtrip")
    func generateAndParseRoundtrip() throws {
        let feed1 = Feed(
            title: "Roundtrip Feed", url: URL(string: "https://roundtrip.com/feed.xml")!)
        feed1.homePageURL = URL(string: "https://roundtrip.com")

        // Generate OPML
        let data = try opmlService.generate(feeds: [feed1], title: "Roundtrip Test")

        // Parse it back
        let document = try opmlService.parse(data: data)

        #expect(document.title == "Roundtrip Test")
        #expect(document.allFeeds.count == 1)

        let parsedFeed = document.allFeeds[0]
        #expect(parsedFeed.title == "Roundtrip Feed")
        #expect(parsedFeed.feedURL?.absoluteString == "https://roundtrip.com/feed.xml")
        #expect(parsedFeed.htmlURL?.absoluteString == "https://roundtrip.com")
    }

    @Test("Generate OPML escapes special XML characters")
    func generateOPMLEscapesXML() throws {
        let feed = Feed(
            title: "Feed & <Special> \"Characters\"",
            url: URL(string: "https://example.com/feed.xml")!)

        let data = try opmlService.generate(feeds: [feed], title: "Test")
        let xmlString = String(data: data, encoding: .utf8)!

        #expect(xmlString.contains("Feed &amp; &lt;Special&gt; &quot;Characters&quot;"))
        #expect(!xmlString.contains("Feed & <Special>"))
    }

    // MARK: - OPML Outline Tests

    @Test("OPMLOutline isFeed property")
    func outlineIsFeed() {
        let feedOutline = OPMLOutline(
            title: "Test",
            feedURL: URL(string: "https://example.com/feed.xml"),
            htmlURL: nil,
            children: []
        )

        let folderOutline = OPMLOutline(
            title: "Folder",
            feedURL: nil,
            htmlURL: nil,
            children: [feedOutline]
        )

        #expect(feedOutline.isFeed)
        #expect(!feedOutline.isFolder)
        #expect(!folderOutline.isFeed)
        #expect(folderOutline.isFolder)
    }
}
