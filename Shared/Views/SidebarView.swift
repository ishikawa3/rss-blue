import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: FeedSelection?
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @Query private var allArticles: [Article]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingFeed = false
    @State private var showSettings = false

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
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
        #if os(iOS)
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
                }
            }
        #endif
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
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false

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
        .contextMenu {
            Button(action: { markAllAsRead() }) {
                Label("Mark All as Read", systemImage: "checkmark.circle")
            }

            Divider()

            Button(action: { copyFeedURL() }) {
                Label("Copy Feed URL", systemImage: "doc.on.doc")
            }

            if let homeURL = feed.homePageURL {
                Link(destination: homeURL) {
                    Label("Open Website", systemImage: "safari")
                }
            }

            Divider()

            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete Feed", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete \"\(feed.title)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteFeed()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will also delete all \(feed.articles?.count ?? 0) articles from this feed.")
        }
    }

    private func markAllAsRead() {
        for article in feed.articles ?? [] {
            article.isRead = true
        }
    }

    private func copyFeedURL() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(feed.url.absoluteString, forType: .string)
        #else
            UIPasteboard.general.string = feed.url.absoluteString
        #endif
    }

    private func deleteFeed() {
        modelContext.delete(feed)
    }
}

#Preview {
    SidebarView(selection: .constant(.allUnread))
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
