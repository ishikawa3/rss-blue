import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedFeedSelection: FeedSelection? = .allUnread
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isRefreshing = false
    @State private var refreshError: String?
    @State private var showRefreshError = false
    @State private var newArticleCount = 0
    @State private var showRefreshSuccess = false
    @State private var showAddFeed = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.publishedDate, order: .reverse) private var allArticles: [Article]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedFeedSelection, showAddFeed: $showAddFeed)
                #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                #endif
        } content: {
            TimelineView(
                selection: selectedFeedSelection,
                selectedArticle: $selectedArticle,
                onRefresh: refreshFeeds
            )
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
            #endif
        } detail: {
            ArticleDetailView(article: selectedArticle)
        }
        #if os(macOS)
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 900, minHeight: 600)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await refreshFeeds() } }) {
                        if isRefreshing {
                            ProgressView()
                            .controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                    .help("Refresh all feeds (⌘R)")
                }
            }
            .focusedSceneValue(\.selectedArticle, $selectedArticle)
            .focusedSceneValue(\.feedSelection, $selectedFeedSelection)
            .focusedSceneValue(\.showAddFeed, $showAddFeed)
            .focusedSceneValue(\.refreshAction, refreshFeeds)
            .focusedSceneValue(\.markAllAsReadAction, markAllAsRead)
        #endif
        .alert("Refresh Error", isPresented: $showRefreshError) {
            Button("OK") { showRefreshError = false }
        } message: {
            Text(refreshError ?? "Failed to refresh feeds")
        }
        .alert("Refresh Complete", isPresented: $showRefreshSuccess) {
            Button("OK") { showRefreshSuccess = false }
        } message: {
            if newArticleCount > 0 {
                Text("Found \(newArticleCount) new article\(newArticleCount == 1 ? "" : "s")")
            } else {
                Text("No new articles found")
            }
        }
    }

    @MainActor
    private func refreshFeeds() async {
        isRefreshing = true

        let feedService = FeedService(modelContext: modelContext)

        do {
            newArticleCount = try await feedService.refreshAllFeeds()
            showRefreshSuccess = true
        } catch {
            refreshError = error.localizedDescription
            showRefreshError = true
        }

        isRefreshing = false
    }

    private func markAllAsRead() {
        let articlesToMark: [Article]

        switch selectedFeedSelection {
        case .allUnread:
            articlesToMark = allArticles.filter { !$0.isRead }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            articlesToMark = allArticles.filter { article in
                guard let date = article.publishedDate else { return false }
                return date >= today && !article.isRead
            }
        case .starred:
            articlesToMark = allArticles.filter { $0.isStarred && !$0.isRead }
        case .feed(let feed):
            articlesToMark = allArticles.filter { $0.feed == feed && !$0.isRead }
        case .folder(let folder):
            let folderFeeds = folder.feeds ?? []
            articlesToMark = allArticles.filter { article in
                guard let feedId = article.feed?.id else { return false }
                return folderFeeds.contains { $0.id == feedId } && !article.isRead
            }
        case nil:
            articlesToMark = []
        }

        for article in articlesToMark {
            article.isRead = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Feed.self, Article.self, Folder.self], inMemory: true)
}
