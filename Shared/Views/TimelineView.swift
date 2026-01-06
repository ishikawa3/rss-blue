import SwiftData
import SwiftUI

struct TimelineView: View {
    let selection: FeedSelection?
    @Binding var selectedArticle: Article?
    var onRefresh: (() async -> Void)?
    @Query(sort: \Article.publishedDate, order: .reverse) private var allArticles: [Article]

    private var articles: [Article] {
        guard let selection = selection else { return allArticles }

        switch selection {
        case .allUnread:
            return allArticles.filter { !$0.isRead }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return allArticles.filter { article in
                guard let date = article.publishedDate else { return false }
                return date >= today
            }
        case .starred:
            return allArticles.filter { $0.isStarred }
        case .feed(let feed):
            return allArticles.filter { $0.feed == feed }
        }
    }

    private var navigationTitle: String {
        selection?.title ?? "All Articles"
    }

    var body: some View {
        List(selection: $selectedArticle) {
            ForEach(articles) { article in
                ArticleRow(article: article)
                    .tag(article as Article?)
            }
        }
        .listStyle(.plain)
        .navigationTitle(navigationTitle)
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: emptyStateImage,
                    description: Text(emptyStateDescription)
                )
            }
        }
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button(action: markAllAsRead) {
                        Label("Mark All as Read", systemImage: "checkmark.circle")
                    }
                    .disabled(articles.filter { !$0.isRead }.isEmpty)
                }
            #endif
        }
        #if os(iOS)
            .refreshable {
                await onRefresh?()
            }
        #endif
    }

    private var emptyStateTitle: String {
        switch selection {
        case .allUnread:
            return "All Caught Up"
        case .today:
            return "Nothing New Today"
        case .starred:
            return "No Starred Articles"
        case .feed:
            return "No Articles"
        case nil:
            return "No Articles"
        }
    }

    private var emptyStateImage: String {
        switch selection {
        case .allUnread:
            return "checkmark.circle"
        case .today:
            return "calendar"
        case .starred:
            return "star"
        case .feed, nil:
            return "newspaper"
        }
    }

    private var emptyStateDescription: String {
        switch selection {
        case .allUnread:
            return "You've read all your articles"
        case .today:
            return "Check back later for new articles"
        case .starred:
            return "Star articles to save them here"
        case .feed, nil:
            return "Add a feed to get started"
        }
    }

    private func markAllAsRead() {
        for article in articles where !article.isRead {
            article.isRead = true
        }
    }
}

struct ArticleRow: View {
    let article: Article
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if !article.isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }

                Text(article.feed?.title ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let date = article.publishedDate {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(article.title)
                .font(.headline)
                .fontWeight(article.isRead ? .regular : .semibold)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .lineLimit(2)

            if let summary = article.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if article.isStarred {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            article.isRead = true
        }
        #if os(iOS)
            .swipeActions(edge: .leading) {
                Button {
                    article.isRead.toggle()
                } label: {
                    Label(
                        article.isRead ? "Unread" : "Read",
                        systemImage: article.isRead ? "circle" : "checkmark.circle"
                    )
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    article.isStarred.toggle()
                } label: {
                    Label(
                        article.isStarred ? "Unstar" : "Star",
                        systemImage: article.isStarred ? "star.slash" : "star.fill"
                    )
                }
                .tint(.yellow)
            }
        #endif
        .contextMenu {
            Button {
                article.isRead.toggle()
            } label: {
                Label(
                    article.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: article.isRead ? "circle" : "checkmark.circle"
                )
            }

            Button {
                article.isStarred.toggle()
            } label: {
                Label(
                    article.isStarred ? "Remove Star" : "Add Star",
                    systemImage: article.isStarred ? "star.slash" : "star.fill"
                )
            }

            Divider()

            if let url = article.url {
                Link(destination: url) {
                    Label("Open in Browser", systemImage: "safari")
                }

                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

#Preview {
    TimelineView(selection: .allUnread, selectedArticle: .constant(nil), onRefresh: nil)
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
