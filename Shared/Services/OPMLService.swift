import Foundation

/// Represents a parsed OPML outline item
struct OPMLOutline: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let feedURL: URL?
    let htmlURL: URL?
    let children: [OPMLOutline]

    /// Whether this is a feed (has xmlUrl) or a folder (has children)
    var isFeed: Bool {
        feedURL != nil
    }

    var isFolder: Bool {
        !children.isEmpty && feedURL == nil
    }
}

/// Represents a parsed OPML document
struct OPMLDocument {
    let title: String
    let dateCreated: Date?
    let outlines: [OPMLOutline]

    /// Returns all feeds in a flat list
    var allFeeds: [OPMLOutline] {
        flattenFeeds(outlines)
    }

    private func flattenFeeds(_ outlines: [OPMLOutline]) -> [OPMLOutline] {
        var feeds: [OPMLOutline] = []
        for outline in outlines {
            if outline.isFeed {
                feeds.append(outline)
            }
            feeds.append(contentsOf: flattenFeeds(outline.children))
        }
        return feeds
    }
}

/// Errors that can occur during OPML parsing
enum OPMLError: LocalizedError {
    case invalidData
    case parsingFailed(String)
    case noFeeds
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid OPML data"
        case .parsingFailed(let reason):
            return "Failed to parse OPML: \(reason)"
        case .noFeeds:
            return "No feeds found in OPML file"
        case .exportFailed(let reason):
            return "Failed to export OPML: \(reason)"
        }
    }
}

/// Service for parsing and generating OPML files
final class OPMLService {

    // MARK: - Parsing

    /// Parses OPML data into a document
    /// - Parameter data: The OPML file data
    /// - Returns: The parsed OPML document
    func parse(data: Data) throws -> OPMLDocument {
        let parser = OPMLParser()
        return try parser.parse(data: data)
    }

    /// Parses OPML from a file URL
    /// - Parameter url: The file URL
    /// - Returns: The parsed OPML document
    func parse(fileURL: URL) throws -> OPMLDocument {
        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    // MARK: - Generation

    /// Generates OPML data from feeds
    /// - Parameters:
    ///   - feeds: The feeds to export
    ///   - title: The title for the OPML document
    /// - Returns: The generated OPML data
    func generate(feeds: [Feed], title: String = "RSS Blue Subscriptions") throws -> Data {
        let generator = OPMLGenerator()
        return try generator.generate(feeds: feeds, title: title)
    }
}

// MARK: - OPML Parser

private class OPMLParser: NSObject, XMLParserDelegate {
    private var document: OPMLDocument?
    private var title = "Untitled"
    private var dateCreated: Date?
    private var outlineStack: [[OPMLOutline]] = [[]]
    private var currentElement = ""
    private var currentText = ""
    private var parseError: Error?

    func parse(data: Data) throws -> OPMLDocument {
        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            if let document = document {
                return document
            } else {
                throw OPMLError.parsingFailed("Document not created")
            }
        } else if let error = parseError {
            throw error
        } else if let error = parser.parserError {
            throw OPMLError.parsingFailed(error.localizedDescription)
        } else {
            throw OPMLError.invalidData
        }
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        if elementName == "outline" {
            // Check if this is a feed or a folder
            if let xmlUrl = attributeDict["xmlUrl"], let url = URL(string: xmlUrl) {
                // This is a feed
                let title = attributeDict["title"] ?? attributeDict["text"] ?? "Untitled"
                let htmlURL = attributeDict["htmlUrl"].flatMap { URL(string: $0) }
                let outline = OPMLOutline(
                    title: title, feedURL: url, htmlURL: htmlURL, children: [])
                outlineStack[outlineStack.count - 1].append(outline)
            } else {
                // This is a folder, push a new level
                outlineStack.append([])
            }
        }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?
    ) {
        if elementName == "title" && currentElement == "title" {
            title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if elementName == "dateCreated" {
            let formatter = ISO8601DateFormatter()
            dateCreated = formatter.date(
                from: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if elementName == "outline" {
            // Check if we were in a folder (has children on stack)
            if outlineStack.count > 1 {
                let children = outlineStack.removeLast()
                if !children.isEmpty || outlineStack.count > 1 {
                    // This was a folder, create folder outline
                    // Note: We need to handle this case better - for now, just flatten
                    outlineStack[outlineStack.count - 1].append(contentsOf: children)
                }
            }
        } else if elementName == "opml" {
            document = OPMLDocument(
                title: title,
                dateCreated: dateCreated,
                outlines: outlineStack.first ?? []
            )
        }

        currentElement = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = OPMLError.parsingFailed(parseError.localizedDescription)
    }
}

// MARK: - OPML Generator

private class OPMLGenerator {
    func generate(feeds: [Feed], title: String) throws -> Data {
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <opml version="2.0">
                <head>
                    <title>\(escapeXML(title))</title>
                    <dateCreated>\(ISO8601DateFormatter().string(from: Date()))</dateCreated>
                </head>
                <body>

            """

        for feed in feeds {
            xml += "        <outline "
            xml += "type=\"rss\" "
            xml += "text=\"\(escapeXML(feed.title))\" "
            xml += "title=\"\(escapeXML(feed.title))\" "
            xml += "xmlUrl=\"\(escapeXML(feed.url.absoluteString))\" "
            if let homeURL = feed.homePageURL {
                xml += "htmlUrl=\"\(escapeXML(homeURL.absoluteString))\" "
            }
            xml += "/>\n"
        }

        xml += """
                </body>
            </opml>
            """

        guard let data = xml.data(using: .utf8) else {
            throw OPMLError.exportFailed("Failed to encode XML")
        }

        return data
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
