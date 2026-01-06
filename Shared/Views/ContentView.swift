import SwiftUI

struct ContentView: View {
    @State private var selectedFeedSelection: FeedSelection? = .allUnread
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedFeedSelection)
                #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                #endif
        } content: {
            TimelineView(selection: selectedFeedSelection, selectedArticle: $selectedArticle)
                #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                #endif
        } detail: {
            ArticleDetailView(article: selectedArticle)
        }
        #if os(macOS)
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
