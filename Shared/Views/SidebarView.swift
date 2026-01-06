import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedFeed: Feed?
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List(selection: $selectedFeed) {
            Section("Smart Feeds") {
                Label("All Unread", systemImage: "circle.badge")
                    .tag(nil as Feed?)
                Label("Today", systemImage: "calendar")
                Label("Starred", systemImage: "star")
            }
            
            Section("Feeds") {
                ForEach(feeds) { feed in
                    FeedRow(feed: feed)
                        .tag(feed as Feed?)
                }
                .onDelete(perform: deleteFeeds)
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("RSS Blue")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Label("Add Feed", systemImage: "plus")
                }
            }
            #endif
        }
    }
    
    private func deleteFeeds(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(feeds[index])
        }
    }
}

struct FeedRow: View {
    let feed: Feed
    
    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.up.forward")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading) {
                Text(feed.title)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if feed.unreadCount > 0 {
                Text("\(feed.unreadCount)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    SidebarView(selectedFeed: .constant(nil))
        .modelContainer(for: Feed.self, inMemory: true)
}
