import FeedKit
import Foundation

/// Errors that can occur during feed parsing
enum FeedParserError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(String)
    case unknownFeedType
    case emptyFeed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feed URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .unknownFeedType:
            return "Unknown or unsupported feed type"
        case .emptyFeed:
            return "Feed contains no items"
        }
    }
}

/// Represents parsed feed metadata
struct ParsedFeed {
    let title: String
    let description: String?
    let homePageURL: URL?
    let imageURL: URL?
    let articles: [ParsedArticle]
}

/// Represents a parsed article from a feed
struct ParsedArticle {
    let id: String
    let title: String
    let summary: String?
    let contentHTML: String?
    let url: URL?
    let author: String?
    let publishedDate: Date?
}

/// Service for fetching and parsing RSS/Atom/JSON feeds
actor FeedParserService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches and parses a feed from the given URL
    /// - Parameter url: The feed URL
    /// - Returns: A parsed feed with metadata and articles
    func fetchAndParse(url: URL) async throws -> ParsedFeed {
        let (data, response) = try await fetchData(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw FeedParserError.networkError(
                NSError(
                    domain: "FeedParser", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }

        return try parse(data: data, feedURL: url)
    }

    /// Validates if a URL points to a valid feed
    /// - Parameter url: The URL to validate
    /// - Returns: The parsed feed if valid
    func validateFeed(url: URL) async throws -> ParsedFeed {
        return try await fetchAndParse(url: url)
    }

    // MARK: - Private Methods

    private func fetchData(from url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch {
            throw FeedParserError.networkError(error)
        }
    }

    private func parse(data: Data, feedURL: URL) throws -> ParsedFeed {
        let parser = FeedParser(data: data)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            switch feed {
            case .rss(let rssFeed):
                return try parseRSSFeed(rssFeed, feedURL: feedURL)
            case .atom(let atomFeed):
                return try parseAtomFeed(atomFeed, feedURL: feedURL)
            case .json(let jsonFeed):
                return try parseJSONFeed(jsonFeed, feedURL: feedURL)
            }
        case .failure(let error):
            throw FeedParserError.parsingError(error.localizedDescription)
        }
    }

    // MARK: - RSS Parsing

    private func parseRSSFeed(_ feed: RSSFeed, feedURL: URL) throws -> ParsedFeed {
        let title = feed.title ?? feedURL.host ?? "Unknown Feed"

        let articles = (feed.items ?? []).compactMap { item -> ParsedArticle? in
            guard let itemTitle = item.title else { return nil }

            let id = item.guid?.value ?? item.link ?? UUID().uuidString

            return ParsedArticle(
                id: id,
                title: itemTitle,
                summary: item.description?.strippingHTMLTags(),
                contentHTML: item.content?.contentEncoded ?? item.description,
                url: item.link.flatMap { URL(string: $0) },
                author: item.author ?? item.dublinCore?.dcCreator,
                publishedDate: item.pubDate
            )
        }

        return ParsedFeed(
            title: title,
            description: feed.description,
            homePageURL: feed.link.flatMap { URL(string: $0) },
            imageURL: feed.image?.url.flatMap { URL(string: $0) },
            articles: articles
        )
    }

    // MARK: - Atom Parsing

    private func parseAtomFeed(_ feed: AtomFeed, feedURL: URL) throws -> ParsedFeed {
        let title = feed.title ?? feedURL.host ?? "Unknown Feed"

        let articles = (feed.entries ?? []).compactMap { entry -> ParsedArticle? in
            guard let entryTitle = entry.title else { return nil }

            let id = entry.id ?? entry.links?.first?.attributes?.href ?? UUID().uuidString
            let link =
                entry.links?.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href
                ?? entry.links?.first?.attributes?.href

            return ParsedArticle(
                id: id,
                title: entryTitle,
                summary: entry.summary?.value?.strippingHTMLTags(),
                contentHTML: entry.content?.value,
                url: link.flatMap { URL(string: $0) },
                author: entry.authors?.first?.name,
                publishedDate: entry.published ?? entry.updated
            )
        }

        let homePageLink =
            feed.links?.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href
            ?? feed.links?.first?.attributes?.href

        return ParsedFeed(
            title: title,
            description: feed.subtitle?.value,
            homePageURL: homePageLink.flatMap { URL(string: $0) },
            imageURL: feed.logo.flatMap { URL(string: $0) },
            articles: articles
        )
    }

    // MARK: - JSON Feed Parsing

    private func parseJSONFeed(_ feed: JSONFeed, feedURL: URL) throws -> ParsedFeed {
        let title = feed.title ?? feedURL.host ?? "Unknown Feed"

        let articles = (feed.items ?? []).compactMap { item -> ParsedArticle? in
            guard let itemTitle = item.title ?? item.contentText?.prefix(50).description else {
                return nil
            }

            let id = item.id ?? item.url ?? UUID().uuidString

            return ParsedArticle(
                id: id,
                title: itemTitle,
                summary: item.summary,
                contentHTML: item.contentHtml ?? item.contentText,
                url: item.url.flatMap { URL(string: $0) },
                author: item.author?.name,
                publishedDate: item.datePublished
            )
        }

        return ParsedFeed(
            title: title,
            description: feed.description,
            homePageURL: feed.homePageURL.flatMap { URL(string: $0) },
            imageURL: feed.icon.flatMap { URL(string: $0) }
                ?? feed.favicon.flatMap { URL(string: $0) },
            articles: articles
        )
    }
}
