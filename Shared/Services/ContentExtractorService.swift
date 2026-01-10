import Foundation

/// Errors that can occur during content extraction
enum ContentExtractorError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidHTML
    case noContentFound
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid article URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidHTML:
            return "Invalid HTML content"
        case .noContentFound:
            return "Could not find main content"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        }
    }
}

/// Result of content extraction
struct ExtractedContent {
    let title: String?
    let content: String
    let textContent: String
    let excerpt: String?
    let author: String?
}

/// Service for extracting full article content from web pages
actor ContentExtractorService {
    private let session: URLSession

    /// Elements that typically contain main content
    private static let contentSelectors = [
        "article", "main", "[role=\"main\"]",
        ".post-content", ".article-content", ".entry-content",
        ".post-body", ".article-body", ".story-body",
        ".content", "#content", ".post", "#post"
    ]

    /// Elements to remove (ads, navigation, etc.)
    private static let removePatterns = [
        "nav", "header", "footer", "aside",
        ".sidebar", ".navigation", ".menu", ".nav",
        ".advertisement", ".ad", ".ads", ".advert",
        ".social-share", ".share-buttons", ".social",
        ".comments", "#comments", ".comment-section",
        ".related-posts", ".recommended", ".popular",
        "script", "style", "noscript", "iframe",
        ".cookie-banner", ".newsletter", ".subscribe",
        "[role=\"navigation\"]", "[role=\"banner\"]",
        "[role=\"complementary\"]", "[aria-hidden=\"true\"]"
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Extracts the full content from an article URL
    /// - Parameter url: The article URL
    /// - Returns: The extracted content
    func extractContent(from url: URL) async throws -> ExtractedContent {
        let html = try await fetchHTML(from: url)
        return try extractContent(from: html, baseURL: url)
    }

    // MARK: - Private Methods

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                        forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ContentExtractorError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw ContentExtractorError.networkError(
                NSError(domain: "ContentExtractor", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }

        // Try to detect encoding from response
        var encoding = String.Encoding.utf8
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           let charset = contentType.components(separatedBy: "charset=").last?.trimmingCharacters(in: .whitespaces) {
            if let detectedEncoding = String.Encoding(ianaCharsetName: charset) {
                encoding = detectedEncoding
            }
        }

        guard let html = String(data: data, encoding: encoding)
                ?? String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ContentExtractorError.invalidHTML
        }

        return html
    }

    func extractContent(from html: String, baseURL: URL) throws -> ExtractedContent {
        // Clean up the HTML first
        var cleanedHTML = html

        // Remove unwanted elements
        cleanedHTML = removeUnwantedElements(from: cleanedHTML)

        // Extract metadata
        let title = extractTitle(from: html)
        let author = extractAuthor(from: html)

        // Try to find main content
        var content = extractMainContent(from: cleanedHTML)

        if content.isEmpty {
            // Fallback: try to extract from body
            content = extractBodyContent(from: cleanedHTML)
        }

        if content.isEmpty {
            throw ContentExtractorError.noContentFound
        }

        // Resolve relative URLs
        content = resolveRelativeURLs(in: content, baseURL: baseURL)

        // Clean up the extracted content
        content = cleanupContent(content)

        // Generate plain text and excerpt
        let textContent = content.strippingHTMLTags()
        let excerpt = generateExcerpt(from: textContent)

        return ExtractedContent(
            title: title,
            content: content,
            textContent: textContent,
            excerpt: excerpt,
            author: author
        )
    }

    private func removeUnwantedElements(from html: String) -> String {
        var result = html

        // Remove script tags and their content
        result = result.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )

        // Remove style tags and their content
        result = result.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove noscript tags
        result = result.replacingOccurrences(
            of: "<noscript[^>]*>[\\s\\S]*?</noscript>",
            with: "",
            options: .regularExpression
        )

        // Remove comments
        result = result.replacingOccurrences(
            of: "<!--[\\s\\S]*?-->",
            with: "",
            options: .regularExpression
        )

        // Remove common unwanted elements by class/id patterns
        let unwantedPatterns = [
            "<nav[^>]*>[\\s\\S]*?</nav>",
            "<header[^>]*>[\\s\\S]*?</header>",
            "<footer[^>]*>[\\s\\S]*?</footer>",
            "<aside[^>]*>[\\s\\S]*?</aside>",
            "<iframe[^>]*>[\\s\\S]*?</iframe>",
            "<form[^>]*>[\\s\\S]*?</form>"
        ]

        for pattern in unwantedPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Remove elements with ad/social/nav classes
        let classPatterns = [
            "class=\"[^\"]*\\b(ad|ads|advert|advertisement|social|share|comment|sidebar|nav|menu|footer|header)\\b[^\"]*\"",
            "id=\"[^\"]*\\b(ad|ads|advert|advertisement|social|share|comment|sidebar|nav|menu|footer|header)\\b[^\"]*\""
        ]

        for pattern in classPatterns {
            // Find and remove elements with these classes/ids
            if let regex = try? NSRegularExpression(pattern: "<[^>]*\(pattern)[^>]*>", options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }

        return result
    }

    private func extractTitle(from html: String) -> String? {
        // Try og:title first
        if let ogTitle = extractMetaContent(from: html, property: "og:title") {
            return ogTitle
        }

        // Try regular title tag
        let titlePattern = "<title[^>]*>([^<]+)</title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let titleRange = Range(match.range(at: 1), in: html) {
            return String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func extractAuthor(from html: String) -> String? {
        // Try meta author
        if let author = extractMetaContent(from: html, name: "author") {
            return author
        }

        // Try article:author
        if let author = extractMetaContent(from: html, property: "article:author") {
            return author
        }

        return nil
    }

    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=\"\(property)\"[^>]*content=\"([^\"]+)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }

        // Try reverse order (content before property)
        let reversePattern = "<meta[^>]*content=\"([^\"]+)\"[^>]*property=\"\(property)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: reversePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }

        return nil
    }

    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=\"\(name)\"[^>]*content=\"([^\"]+)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }

        // Try reverse order
        let reversePattern = "<meta[^>]*content=\"([^\"]+)\"[^>]*name=\"\(name)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: reversePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }

        return nil
    }

    private func extractMainContent(from html: String) -> String {
        // Try to find article tag first (most semantic)
        if let articleContent = extractTagContent(from: html, tag: "article") {
            let cleaned = articleContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && cleaned.count > 100 {
                return cleaned
            }
        }

        // Try main tag
        if let mainContent = extractTagContent(from: html, tag: "main") {
            let cleaned = mainContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && cleaned.count > 100 {
                return cleaned
            }
        }

        // Try common content class patterns
        let contentPatterns = [
            "class=\"[^\"]*\\bcontent\\b[^\"]*\"",
            "class=\"[^\"]*\\bpost\\b[^\"]*\"",
            "class=\"[^\"]*\\bentry\\b[^\"]*\"",
            "class=\"[^\"]*\\barticle\\b[^\"]*\"",
            "id=\"content\"",
            "id=\"post\"",
            "id=\"article\""
        ]

        for pattern in contentPatterns {
            if let content = extractElementByPattern(from: html, pattern: pattern) {
                let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count > 100 {
                    return cleaned
                }
            }
        }

        return ""
    }

    private func extractBodyContent(from html: String) -> String {
        if let bodyContent = extractTagContent(from: html, tag: "body") {
            return bodyContent
        }
        return ""
    }

    private func extractTagContent(from html: String, tag: String) -> String? {
        // Simple extraction - find opening and closing tags
        let openPattern = "<\(tag)[^>]*>"
        let closePattern = "</\(tag)>"

        guard let openRegex = try? NSRegularExpression(pattern: openPattern, options: .caseInsensitive),
              let openMatch = openRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let openRange = Range(openMatch.range, in: html) else {
            return nil
        }

        let startIndex = openRange.upperBound

        guard let closeRegex = try? NSRegularExpression(pattern: closePattern, options: .caseInsensitive),
              let closeMatch = closeRegex.firstMatch(in: html, range: NSRange(startIndex..., in: html)),
              let closeRange = Range(closeMatch.range, in: html) else {
            return nil
        }

        let endIndex = closeRange.lowerBound

        return String(html[startIndex..<endIndex])
    }

    private func extractElementByPattern(from html: String, pattern: String) -> String? {
        // Find element with the given class/id pattern and extract its content
        guard let regex = try? NSRegularExpression(pattern: "<(\\w+)[^>]*\(pattern)[^>]*>", options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let fullRange = Range(match.range, in: html),
              let tagRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let tagName = String(html[tagRange])
        let startIndex = fullRange.upperBound

        // Find the matching closing tag (simplified - doesn't handle nested tags with same name)
        let closePattern = "</\(tagName)>"
        guard let closeRegex = try? NSRegularExpression(pattern: closePattern, options: .caseInsensitive),
              let closeMatch = closeRegex.firstMatch(in: html, range: NSRange(startIndex..., in: html)),
              let closeRange = Range(closeMatch.range, in: html) else {
            return nil
        }

        let endIndex = closeRange.lowerBound
        return String(html[startIndex..<endIndex])
    }

    func resolveRelativeURLs(in html: String, baseURL: URL) -> String {
        var result = html

        // Resolve src attributes (images, videos, etc.)
        result = resolveAttribute(in: result, attribute: "src", baseURL: baseURL)

        // Resolve href attributes (links)
        result = resolveAttribute(in: result, attribute: "href", baseURL: baseURL)

        // Resolve srcset attributes
        result = resolveSrcset(in: result, baseURL: baseURL)

        return result
    }

    private func resolveAttribute(in html: String, attribute: String, baseURL: URL) -> String {
        let pattern = "\(attribute)=\"([^\"]+)\""

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return html
        }

        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        // Process matches in reverse order to maintain correct indices
        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }

            let urlString = String(result[urlRange])

            // Skip data URLs and already absolute URLs
            if urlString.hasPrefix("data:") ||
               urlString.hasPrefix("http://") ||
               urlString.hasPrefix("https://") ||
               urlString.hasPrefix("//") {
                continue
            }

            // Resolve relative URL
            if let resolvedURL = URL(string: urlString, relativeTo: baseURL)?.absoluteString {
                let replacement = "\(attribute)=\"\(resolvedURL)\""
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    private func resolveSrcset(in html: String, baseURL: URL) -> String {
        let pattern = "srcset=\"([^\"]+)\""

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return html
        }

        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches.reversed() {
            guard let srcsetRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }

            let srcset = String(result[srcsetRange])
            let resolvedSrcset = srcset.components(separatedBy: ",").map { entry -> String in
                let parts = entry.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                guard let urlPart = parts.first else { return entry }

                if urlPart.hasPrefix("http://") || urlPart.hasPrefix("https://") || urlPart.hasPrefix("//") {
                    return entry
                }

                if let resolvedURL = URL(string: urlPart, relativeTo: baseURL)?.absoluteString {
                    var newParts = parts
                    newParts[0] = resolvedURL
                    return newParts.joined(separator: " ")
                }

                return entry
            }.joined(separator: ", ")

            let replacement = "srcset=\"\(resolvedSrcset)\""
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    private func cleanupContent(_ html: String) -> String {
        var result = html

        // Remove empty paragraphs
        result = result.replacingOccurrences(
            of: "<p[^>]*>\\s*</p>",
            with: "",
            options: .regularExpression
        )

        // Remove empty divs
        result = result.replacingOccurrences(
            of: "<div[^>]*>\\s*</div>",
            with: "",
            options: .regularExpression
        )

        // Remove excessive whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        // Trim
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private func generateExcerpt(from text: String, maxLength: Int = 200) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= maxLength {
            return cleaned
        }

        // Find a good breaking point
        let truncated = String(cleaned.prefix(maxLength))

        // Try to break at a sentence boundary
        if let lastPeriod = truncated.lastIndex(of: ".") {
            let index = truncated.index(after: lastPeriod)
            return String(truncated[..<index])
        }

        // Try to break at a word boundary
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }

        return truncated + "..."
    }
}

// MARK: - String.Encoding extension

extension String.Encoding {
    init?(ianaCharsetName: String) {
        let lowercased = ianaCharsetName.lowercased()

        switch lowercased {
        case "utf-8", "utf8":
            self = .utf8
        case "iso-8859-1", "latin1":
            self = .isoLatin1
        case "iso-8859-2", "latin2":
            self = .isoLatin2
        case "windows-1252", "cp1252":
            self = .windowsCP1252
        case "shift_jis", "shift-jis", "sjis":
            self = .shiftJIS
        case "euc-jp":
            self = .japaneseEUC
        case "euc-kr":
            self = .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        case "gb2312", "gbk":
            self = .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        default:
            return nil
        }
    }
}
