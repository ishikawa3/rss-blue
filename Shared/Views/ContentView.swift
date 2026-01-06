import SwiftUI

struct ContentView: View {
    @State private var selectedFeed: Feed?
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedFeed: $selectedFeed)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                #endif
        } content: {
            TimelineView(feed: selectedFeed, selectedArticle: $selectedArticle)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                #endif
        } detail: {
            ArticleDetailView(article: selectedArticle)
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

#Preview {
    ContentView()
}
