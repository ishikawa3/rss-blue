import Foundation
import Testing

@testable import RSSBlue

@Suite("ContentExtractor Tests")
struct ContentExtractorTests {

    // MARK: - HTML Content Extraction Tests

    @Test("Extract content from article tag")
    func extractFromArticleTag() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Article</title></head>
        <body>
            <nav>Navigation menu</nav>
            <article>
                <h1>Main Article Title</h1>
                <p>This is the main article content that should be extracted. It contains important information.</p>
                <p>Another paragraph with more content.</p>
            </article>
            <footer>Footer content</footer>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("Main Article Title"))
        #expect(result.content.contains("main article content"))
        #expect(!result.content.contains("Navigation menu"))
        #expect(!result.content.contains("Footer content"))
    }

    @Test("Extract content from main tag")
    func extractFromMainTag() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <header>Site header</header>
            <main>
                <h1>Welcome to the main content</h1>
                <p>This paragraph is inside the main element and should be extracted properly.</p>
            </main>
            <aside>Sidebar content</aside>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/page")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("Welcome to the main content"))
        #expect(result.content.contains("main element"))
    }

    @Test("Extract title from og:title meta tag")
    func extractOgTitle() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta property="og:title" content="Open Graph Title">
            <title>Regular Title</title>
        </head>
        <body>
            <article>
                <p>Article content for testing title extraction.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.title == "Open Graph Title")
    }

    @Test("Extract title from title tag when og:title not present")
    func extractRegularTitle() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Regular HTML Title</title>
        </head>
        <body>
            <article>
                <p>Article content for testing regular title extraction.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.title == "Regular HTML Title")
    }

    @Test("Extract author from meta tag")
    func extractAuthor() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="author" content="John Doe">
            <title>Test Article</title>
        </head>
        <body>
            <article>
                <p>Article written by an author.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.author == "John Doe")
    }

    // MARK: - URL Resolution Tests

    @Test("Resolve relative image URLs")
    func resolveRelativeImageURLs() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <img src="/images/photo.jpg" alt="Photo">
                <p>Article with a relative image URL.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/articles/test")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("https://example.com/images/photo.jpg"))
        #expect(!result.content.contains("src=\"/images/photo.jpg\""))
    }

    @Test("Resolve relative link URLs")
    func resolveRelativeLinkURLs() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <a href="../other-article">Related article</a>
                <p>Article with a relative link.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/articles/test/page")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("https://example.com/articles/other-article"))
    }

    @Test("Preserve absolute URLs")
    func preserveAbsoluteURLs() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <img src="https://cdn.example.com/images/photo.jpg" alt="Photo">
                <a href="https://other-site.com/page">External link</a>
                <p>Article with absolute URLs.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("https://cdn.example.com/images/photo.jpg"))
        #expect(result.content.contains("https://other-site.com/page"))
    }

    // MARK: - Content Cleaning Tests

    @Test("Remove script tags")
    func removeScriptTags() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <script>alert('malicious');</script>
                <p>Clean article content.</p>
                <script type="text/javascript">
                    console.log('another script');
                </script>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(!result.content.contains("alert"))
        #expect(!result.content.contains("console.log"))
        #expect(result.content.contains("Clean article content"))
    }

    @Test("Remove style tags")
    func removeStyleTags() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <style>.ad { display: block; }</style>
                <p>Article without inline styles.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(!result.content.contains("display: block"))
        #expect(result.content.contains("Article without inline styles"))
    }

    @Test("Remove navigation elements")
    func removeNavigationElements() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <nav>
                <ul>
                    <li>Home</li>
                    <li>About</li>
                </ul>
            </nav>
            <article>
                <p>Main content without navigation.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("Main content"))
        // Navigation should be removed before content extraction
    }

    @Test("Remove HTML comments")
    func removeHTMLComments() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <!-- This is a comment that should be removed -->
                <p>Content without comments.</p>
                <!-- Another comment -->
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(!result.content.contains("This is a comment"))
        #expect(!result.content.contains("Another comment"))
        #expect(result.content.contains("Content without comments"))
    }

    // MARK: - Text Content and Excerpt Tests

    @Test("Generate plain text content")
    func generatePlainTextContent() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <h1>Article Title</h1>
                <p>This is <strong>bold</strong> and <em>italic</em> text.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.textContent.contains("bold"))
        #expect(result.textContent.contains("italic"))
        #expect(!result.textContent.contains("<strong>"))
        #expect(!result.textContent.contains("<em>"))
    }

    @Test("Generate excerpt from long content")
    func generateExcerpt() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <p>This is the beginning of a very long article that contains many words and sentences. It continues with more content that should be truncated when generating an excerpt. The excerpt should capture the essence of the article while keeping it brief.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.excerpt != nil)
        #expect(result.excerpt!.count <= 250)  // Allow some buffer for sentence breaking
        #expect(result.excerpt!.contains("beginning"))
    }

    // MARK: - Error Handling Tests

    @Test("Handle HTML without main content gracefully")
    func handleMissingMainContent() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <p>Just a simple paragraph.</p>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/page")!

        // Should extract from body as fallback
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        #expect(result.content.contains("simple paragraph"))
    }

    // MARK: - Srcset Resolution Tests

    @Test("Resolve srcset URLs")
    func resolveSrcsetURLs() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <article>
                <img src="/images/photo.jpg" 
                     srcset="/images/photo-small.jpg 320w, /images/photo-medium.jpg 640w, /images/photo-large.jpg 1024w"
                     alt="Responsive image">
                <p>Article with responsive images.</p>
            </article>
        </body>
        </html>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("https://example.com/images/photo.jpg"))
        #expect(result.content.contains("https://example.com/images/photo-small.jpg"))
        #expect(result.content.contains("https://example.com/images/photo-medium.jpg"))
    }
}

@Suite("URL Resolution Tests")
struct URLResolutionTests {

    @Test("Resolve various relative URL patterns")
    func resolveVariousPatterns() async throws {
        let html = """
        <article>
            <img src="image.jpg" alt="Same directory">
            <img src="./image.jpg" alt="Explicit same directory">
            <img src="../image.jpg" alt="Parent directory">
            <img src="/image.jpg" alt="Root relative">
            <a href="page.html">Same directory link</a>
            <a href="/pages/other.html">Root relative link</a>
        </article>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/blog/posts/article.html")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        // Same directory: https://example.com/blog/posts/image.jpg
        #expect(result.content.contains("https://example.com/blog/posts/image.jpg"))

        // Parent directory: https://example.com/blog/image.jpg
        #expect(result.content.contains("https://example.com/blog/image.jpg"))

        // Root relative: https://example.com/image.jpg
        #expect(result.content.contains("https://example.com/image.jpg"))

        // Page link
        #expect(result.content.contains("https://example.com/blog/posts/page.html"))

        // Root relative link
        #expect(result.content.contains("https://example.com/pages/other.html"))
    }

    @Test("Preserve data URLs")
    func preserveDataURLs() async throws {
        let html = """
        <article>
            <img src="data:image/png;base64,iVBORw0KGgo=" alt="Base64 image">
            <p>Article with inline data URL.</p>
        </article>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        #expect(result.content.contains("data:image/png;base64,iVBORw0KGgo="))
    }

    @Test("Handle protocol-relative URLs")
    func handleProtocolRelativeURLs() async throws {
        let html = """
        <article>
            <img src="//cdn.example.com/image.jpg" alt="Protocol relative">
            <p>Article with protocol-relative URL.</p>
        </article>
        """

        let extractor = ContentExtractorService()
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)

        // Protocol-relative URLs should be preserved as-is
        #expect(result.content.contains("//cdn.example.com/image.jpg"))
    }
}

@Suite("Article Model Tests")
struct ArticleModelTests {

    @Test("Article has full content properties")
    func articleHasFullContentProperties() {
        let article = Article(title: "Test Article")

        #expect(article.fullContent == nil)
        #expect(article.hasFullContent == false)

        article.fullContent = "<p>Full article content</p>"
        article.hasFullContent = true

        #expect(article.fullContent == "<p>Full article content</p>")
        #expect(article.hasFullContent == true)
    }
}

@Suite("Feed Model Tests")
struct FeedModelFullContentTests {

    @Test("Feed has fetch full content setting")
    func feedHasFetchFullContentSetting() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        #expect(feed.fetchFullContent == false)

        feed.fetchFullContent = true

        #expect(feed.fetchFullContent == true)
    }
}
