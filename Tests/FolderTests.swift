import Foundation
import Testing

@testable import RSSBlue

@Suite("Folder Model Tests")
struct FolderModelTests {

    @Test("Folder initialization")
    func folderInitialization() {
        let folder = Folder(name: "Tech News", sortOrder: 0)

        #expect(folder.name == "Tech News")
        #expect(folder.sortOrder == 0)
        #expect(folder.isExpanded == true)
        #expect(folder.feeds == nil || folder.feeds?.isEmpty == true)
    }

    @Test("Folder with custom sort order")
    func folderWithSortOrder() {
        let folder = Folder(name: "Sports", sortOrder: 5)

        #expect(folder.sortOrder == 5)
    }

    @Test("Folder unread count with no feeds")
    func folderUnreadCountEmpty() {
        let folder = Folder(name: "Empty")

        #expect(folder.unreadCount == 0)
    }

    @Test("Folder all articles with no feeds")
    func folderAllArticlesEmpty() {
        let folder = Folder(name: "Empty")

        #expect(folder.allArticles.isEmpty)
    }
}

@Suite("Folder-Feed Relationship Tests")
struct FolderFeedRelationshipTests {

    @Test("Feed can be assigned to folder")
    func feedAssignedToFolder() {
        let folder = Folder(name: "Tech")
        let feed = Feed(title: "TechCrunch", url: URL(string: "https://techcrunch.com/feed")!)

        feed.folder = folder

        #expect(feed.folder?.name == "Tech")
    }

    @Test("Feed can be unassigned from folder")
    func feedUnassignedFromFolder() {
        let folder = Folder(name: "Tech")
        let feed = Feed(title: "TechCrunch", url: URL(string: "https://techcrunch.com/feed")!)

        feed.folder = folder
        feed.folder = nil

        #expect(feed.folder == nil)
    }

    @Test("Feed sortOrder property exists")
    func feedHasSortOrder() {
        let feed = Feed(title: "Test", url: URL(string: "https://example.com/feed")!)

        #expect(feed.sortOrder == 0)

        feed.sortOrder = 5
        #expect(feed.sortOrder == 5)
    }
}

@Suite("FeedSelection Folder Tests")
struct FeedSelectionFolderTests {

    @Test("FeedSelection folder case title")
    func folderSelectionTitle() {
        let folder = Folder(name: "My Folder")
        let selection = FeedSelection.folder(folder)

        #expect(selection.title == "My Folder")
    }

    @Test("FeedSelection folder case system image")
    func folderSelectionSystemImage() {
        let folder = Folder(name: "My Folder")
        let selection = FeedSelection.folder(folder)

        #expect(selection.systemImage == "folder")
    }

    @Test("FeedSelection folder hashable")
    func folderSelectionHashable() {
        let folder1 = Folder(name: "Folder 1")
        let folder2 = Folder(name: "Folder 2")

        let selection1 = FeedSelection.folder(folder1)
        let selection2 = FeedSelection.folder(folder2)
        let selection1Again = FeedSelection.folder(folder1)

        #expect(selection1 == selection1Again)
        #expect(selection1 != selection2)
    }
}
