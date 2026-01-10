import SwiftData
import SwiftUI

/// Menu bar extra view for macOS
struct MenuBarView: View {
    @Query(
        filter: #Predicate<Article> { !$0.isRead },
        sort: \Article.publishedDate,
        order: .reverse
    ) private var unreadArticles: [Article]

    @Query private var allFeeds: [Feed]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @State private var isRefreshing = false

    /// Maximum number of recent articles to show in the menu
    private let maxRecentArticles = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.vertical, 4)

            // Recent unread articles
            if unreadArticles.isEmpty {
                emptyStateView
            } else {
                recentArticlesSection
            }

            Divider()
                .padding(.vertical, 4)

            // Actions
            actionsSection
        }
        .frame(width: 320)
        .padding(.vertical, 8)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("RSS Blue")
                .font(.headline)

            Spacer()

            if unreadArticles.count > 0 {
                Text("\(unreadArticles.count) unread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("All caught up!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Recent Articles Section

    private var recentArticlesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Unread")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            ForEach(Array(unreadArticles.prefix(maxRecentArticles))) { article in
                MenuBarArticleRow(article: article) {
                    openArticle(article)
                }
            }

            if unreadArticles.count > maxRecentArticles {
                Button(action: openMainWindow) {
                    HStack {
                        Text("View all \(unreadArticles.count) unread articles...")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.forward")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Refresh button
            Button(action: refreshFeeds) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh Feeds")
                    Spacer()
                    Text("⌘R")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(MenuBarButtonStyle())
            .disabled(isRefreshing)
            .keyboardShortcut("r", modifiers: .command)

            // Mark all as read
            Button(action: markAllAsRead) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Mark All as Read")
                    Spacer()
                }
            }
            .buttonStyle(MenuBarButtonStyle())
            .disabled(unreadArticles.isEmpty)

            Divider()
                .padding(.vertical, 4)

            // Open main window
            Button(action: openMainWindow) {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open RSS Blue")
                    Spacer()
                }
            }
            .buttonStyle(MenuBarButtonStyle())

            // Settings
            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(MenuBarButtonStyle())

            Divider()
                .padding(.vertical, 4)

            // Quit
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit RSS Blue")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(MenuBarButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    // MARK: - Actions

    private func openArticle(_ article: Article) {
        article.isRead = true
        // Open the main window and navigate to the article
        openMainWindow()
        // TODO: Navigate to specific article via environment or notification
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func refreshFeeds() {
        isRefreshing = true
        Task {
            let feedService = FeedService(modelContext: modelContext)
            do {
                _ = try await feedService.refreshAllFeeds()
            } catch {
                print("[MenuBar] Refresh failed: \(error)")
            }
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func markAllAsRead() {
        for article in unreadArticles {
            article.isRead = true
        }
    }
}

// MARK: - Article Row

struct MenuBarArticleRow: View {
    let article: Article
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.callout)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        if let feedTitle = article.feed?.title {
                            Text(feedTitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let date = article.publishedDate {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            Text(date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarButtonStyle())
    }
}

// MARK: - Custom Button Style

struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: [Feed.self, Article.self, Folder.self], inMemory: true)
}
