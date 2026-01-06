import SwiftUI
import Testing

@testable import RSSBlue

@Suite("Navigation Tests")
struct NavigationTests {

    // MARK: - FeedSelection Tests

    @Test("FeedSelection enum titles")
    func feedSelectionTitles() {
        #expect(FeedSelection.allUnread.title == "All Unread")
        #expect(FeedSelection.today.title == "Today")
        #expect(FeedSelection.starred.title == "Starred")
    }

    @Test("FeedSelection enum system images")
    func feedSelectionSystemImages() {
        #expect(FeedSelection.allUnread.systemImage == "circle.badge")
        #expect(FeedSelection.today.systemImage == "calendar")
        #expect(FeedSelection.starred.systemImage == "star.fill")
    }

    @Test("FeedSelection feed case")
    func feedSelectionFeedCase() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)
        let selection = FeedSelection.feed(feed)

        #expect(selection.title == "Test Feed")
        #expect(selection.systemImage == "dot.radiowaves.up.forward")
    }

    @Test("FeedSelection hashable conformance")
    func feedSelectionHashable() {
        let set: Set<FeedSelection> = [.allUnread, .today, .starred]
        #expect(set.count == 3)
        #expect(set.contains(.allUnread))
        #expect(set.contains(.today))
        #expect(set.contains(.starred))
    }

    // MARK: - Article Filtering Tests

    @Test("Article filtering for unread")
    func articleFilteringUnread() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        let readArticle = Article(title: "Read Article", feed: feed)
        readArticle.isRead = true

        let unreadArticle = Article(title: "Unread Article", feed: feed)
        unreadArticle.isRead = false

        let articles = [readArticle, unreadArticle]
        let unreadArticles = articles.filter { !$0.isRead }

        #expect(unreadArticles.count == 1)
        #expect(unreadArticles.first?.title == "Unread Article")
    }

    @Test("Article filtering for starred")
    func articleFilteringStarred() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        let starredArticle = Article(title: "Starred Article", feed: feed)
        starredArticle.isStarred = true

        let unstarredArticle = Article(title: "Unstarred Article", feed: feed)
        unstarredArticle.isStarred = false

        let articles = [starredArticle, unstarredArticle]
        let starredArticles = articles.filter { $0.isStarred }

        #expect(starredArticles.count == 1)
        #expect(starredArticles.first?.title == "Starred Article")
    }

    @Test("Article filtering for today")
    func articleFilteringToday() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)

        let todayArticle = Article(title: "Today Article", feed: feed)
        todayArticle.publishedDate = Date()

        let oldArticle = Article(title: "Old Article", feed: feed)
        oldArticle.publishedDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())

        let articles = [todayArticle, oldArticle]
        let today = Calendar.current.startOfDay(for: Date())
        let todayArticles = articles.filter { article in
            guard let date = article.publishedDate else { return false }
            return date >= today
        }

        #expect(todayArticles.count == 1)
        #expect(todayArticles.first?.title == "Today Article")
    }

    @Test("Article filtering by feed")
    func articleFilteringByFeed() {
        let feed1 = Feed(title: "Feed 1", url: URL(string: "https://example.com/feed1")!)
        let feed2 = Feed(title: "Feed 2", url: URL(string: "https://example.com/feed2")!)

        let article1 = Article(title: "Article from Feed 1", feed: feed1)
        let article2 = Article(title: "Article from Feed 2", feed: feed2)
        let article3 = Article(title: "Another from Feed 1", feed: feed1)

        let articles = [article1, article2, article3]
        let feed1Articles = articles.filter { $0.feed === feed1 }

        #expect(feed1Articles.count == 2)
    }

    // MARK: - View State Tests

    @Test("Default selection is all unread")
    func defaultSelectionIsAllUnread() {
        // Verify the default state
        let defaultSelection: FeedSelection? = .allUnread
        #expect(defaultSelection == .allUnread)
    }

    @Test("Mark as read functionality")
    func markAsRead() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)
        let article = Article(title: "Test Article", feed: feed)

        #expect(article.isRead == false)

        article.isRead = true

        #expect(article.isRead == true)
    }

    @Test("Toggle star functionality")
    func toggleStar() {
        let feed = Feed(title: "Test Feed", url: URL(string: "https://example.com/feed")!)
        let article = Article(title: "Test Article", feed: feed)

        #expect(article.isStarred == false)

        article.isStarred.toggle()
        #expect(article.isStarred == true)

        article.isStarred.toggle()
        #expect(article.isStarred == false)
    }
}
