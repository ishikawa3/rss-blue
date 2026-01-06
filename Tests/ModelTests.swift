import Testing
import Foundation
@testable import RSSBlue

@Suite("Feed Model Tests")
struct FeedTests {
    
    @Test("Feed initialization")
    func feedInitialization() {
        let url = URL(string: "https://example.com/feed.xml")!
        let feed = Feed(title: "Test Feed", url: url)
        
        #expect(feed.title == "Test Feed")
        #expect(feed.url == url)
        #expect(feed.id != UUID())
        #expect(feed.articles == nil)
        #expect(feed.unreadCount == 0)
    }
    
    @Test("Feed unread count calculation")
    func feedUnreadCount() {
        let url = URL(string: "https://example.com/feed.xml")!
        let feed = Feed(title: "Test Feed", url: url)
        
        // Initial unread count should be 0
        #expect(feed.unreadCount == 0)
    }
}

@Suite("Article Model Tests")
struct ArticleTests {
    
    @Test("Article initialization")
    func articleInitialization() {
        let article = Article(title: "Test Article")
        
        #expect(article.title == "Test Article")
        #expect(article.isRead == false)
        #expect(article.isStarred == false)
        #expect(article.feed == nil)
    }
    
    @Test("Article with feed")
    func articleWithFeed() {
        let url = URL(string: "https://example.com/feed.xml")!
        let feed = Feed(title: "Test Feed", url: url)
        let article = Article(title: "Test Article", feed: feed)
        
        #expect(article.feed === feed)
    }
    
    @Test("Article read state toggle")
    func articleReadState() {
        let article = Article(title: "Test Article")
        
        #expect(article.isRead == false)
        
        article.isRead = true
        #expect(article.isRead == true)
        
        article.isRead = false
        #expect(article.isRead == false)
    }
    
    @Test("Article starred state toggle")
    func articleStarredState() {
        let article = Article(title: "Test Article")
        
        #expect(article.isStarred == false)
        
        article.isStarred = true
        #expect(article.isStarred == true)
        
        article.isStarred.toggle()
        #expect(article.isStarred == false)
    }
}
