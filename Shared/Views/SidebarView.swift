import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: FeedSelection?
    @Binding var showAddFeed: Bool
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Query(
        filter: #Predicate<Feed> { $0.folder == nil },
        sort: \Feed.sortOrder
    ) private var uncategorizedFeeds: [Feed]
    @Query private var allArticles: [Article]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingFolder = false
    @State private var showSettings = false
    @State private var newFolderName = ""

    init(selection: Binding<FeedSelection?>, showAddFeed: Binding<Bool> = .constant(false)) {
        self._selection = selection
        self._showAddFeed = showAddFeed
    }

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
                // Folders
                ForEach(folders) { folder in
                    FolderRow(folder: folder, selection: $selection)
                }

                // Uncategorized feeds
                ForEach(uncategorizedFeeds) { feed in
                    FeedRow(feed: feed)
                        .tag(FeedSelection.feed(feed))
                }
                .onDelete(perform: deleteUncategorizedFeeds)
            }
        }
        #if os(macOS)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(action: { showAddFeed = true }) {
                        Label("Add Feed", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: { isAddingFolder = true }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
                    Menu {
                        Button(action: { showAddFeed = true }) {
                            Label("Add Feed", systemImage: "plus")
                        }
                        Button(action: { isAddingFolder = true }) {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            #endif
        }
        .sheet(isPresented: $showAddFeed) {
            AddFeedView()
        }
        .alert("New Folder", isPresented: $isAddingFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createFolder()
            }
        } message: {
            Text("Enter a name for the new folder.")
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

    private func deleteUncategorizedFeeds(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(uncategorizedFeeds[index])
        }
    }

    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        let folderService = FolderService(modelContext: modelContext)
        try? folderService.createFolder(name: newFolderName)
        newFolderName = ""
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    @Bindable var folder: Folder
    @Binding var selection: FeedSelection?
    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        DisclosureGroup(isExpanded: $folder.isExpanded) {
            ForEach(folder.feeds ?? []) { feed in
                FeedRow(feed: feed)
                    .tag(FeedSelection.feed(feed))
            }
        } label: {
            HStack {
                Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                    .foregroundStyle(.brown)

                Text(folder.name)

                Spacer()

                if folder.unreadCount > 0 {
                    Text("\(folder.unreadCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.brown.opacity(0.15))
                        .foregroundStyle(.brown)
                        .clipShape(Capsule())
                }
            }
            .tag(FeedSelection.folder(folder))
        }
        #if os(macOS)
            .dropDestination(for: String.self) { items, _ in
                handleDrop(feedIds: items)
            }
        #endif
        .contextMenu {
            Button(action: {
                newName = folder.name
                isRenaming = true
            }) {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .alert("Rename Folder", isPresented: $isRenaming) {
            TextField("Folder Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                renameFolder()
            }
        }
        .confirmationDialog(
            "Delete \"\(folder.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Feeds in this folder will be moved to Uncategorized.")
        }
    }

    private func renameFolder() {
        guard !newName.isEmpty else { return }
        let folderService = FolderService(modelContext: modelContext)
        try? folderService.renameFolder(folder, to: newName)
    }

    private func deleteFolder() {
        let folderService = FolderService(modelContext: modelContext)
        try? folderService.deleteFolder(folder)
    }

    #if os(macOS)
        private func handleDrop(feedIds: [String]) -> Bool {
            let descriptor = FetchDescriptor<Feed>()
            guard let allFeeds = try? modelContext.fetch(descriptor) else { return false }

            let feedsToMove = allFeeds.filter { feedIds.contains($0.id.uuidString) }
            guard !feedsToMove.isEmpty else { return false }

            let folderService = FolderService(modelContext: modelContext)
            try? folderService.moveFeeds(feedsToMove, to: folder)
            return true
        }
    #endif
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
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
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
        #if os(macOS)
            .draggable(feed.id.uuidString)
        #endif
        .contextMenu {
            Button(action: { markAllAsRead() }) {
                Label("Mark All as Read", systemImage: "checkmark.circle")
            }

            Divider()

            // Move to folder menu
            Menu {
                Button(action: { moveFeed(to: nil) }) {
                    Label("Uncategorized", systemImage: "tray")
                    if feed.folder == nil {
                        Image(systemName: "checkmark")
                    }
                }

                Divider()

                ForEach(folders) { folder in
                    Button(action: { moveFeed(to: folder) }) {
                        Label(folder.name, systemImage: "folder")
                        if feed.folder?.id == folder.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label("Move to Folder", systemImage: "folder")
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

    private func moveFeed(to folder: Folder?) {
        let folderService = FolderService(modelContext: modelContext)
        try? folderService.moveFeed(feed, to: folder)
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
        .modelContainer(for: [Feed.self, Article.self, Folder.self], inMemory: true)
}
