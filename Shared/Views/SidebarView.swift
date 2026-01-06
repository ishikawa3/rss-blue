import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: FeedSelection?
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @Query private var allArticles: [Article]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingFeed = false

    private var unreadCount: Int {
        allArticles.filter { !$0.isRead }.count
    }

    private var todayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return allArticles.filter { article in
            guard let date = article.publishedDate else { return false }
            return date >= today && !article.isRead
        }.count
    }

    private var starredCount: Int {
        allArticles.filter { $0.isStarred }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section("Smart Feeds") {
                SmartFeedRow(
                    title: "All Unread",
                    systemImage: "circle.badge",
                    count: unreadCount,
                    accentColor: .blue
                )
                .tag(FeedSelection.allUnread)

                SmartFeedRow(
                    title: "Today",
                    systemImage: "calendar",
                    count: todayCount,
                    accentColor: .orange
                )
                .tag(FeedSelection.today)

                SmartFeedRow(
                    title: "Starred",
                    systemImage: "star.fill",
                    count: starredCount,
                    accentColor: .yellow
                )
                .tag(FeedSelection.starred)
            }

            Section("Feeds") {
                ForEach(feeds) { feed in
                    FeedRow(feed: feed)
                        .tag(FeedSelection.feed(feed))
                }
                .onDelete(perform: deleteFeeds)
            }
        }
        #if os(macOS)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(action: { isAddingFeed = true }) {
                        Label("Add Feed", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        #else
            .listStyle(.insetGrouped)
        #endif
        .navigationTitle("RSS Blue")
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddingFeed = true }) {
                        Label("Add Feed", systemImage: "plus")
                    }
                }
            #endif
        }
        .sheet(isPresented: $isAddingFeed) {
            AddFeedView()
        }
    }

    private func deleteFeeds(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(feeds[index])
        }
    }
}

struct SmartFeedRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let accentColor: Color

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(accentColor)

            Text(title)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.15))
                    .foregroundStyle(accentColor)
                    .clipShape(Capsule())
            }
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
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
    }
}

// Placeholder for Add Feed functionality (Issue #5)
struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Add Feed")
                    .font(.headline)
                Text("Coming in Issue #5")
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 300, minHeight: 200)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.allUnread))
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
