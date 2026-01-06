import SwiftData
import SwiftUI

struct TimelineView: View {
    let selection: FeedSelection?
    @Binding var selectedArticle: Article?
    var onRefresh: (() async -> Void)?
    @Query(sort: \Article.publishedDate, order: .reverse) private var allArticles: [Article]

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    private var filteredArticles: [Article] {
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
        case .folder(let folder):
            let folderFeeds = folder.feeds ?? []
            return allArticles.filter { article in
                guard let feedId = article.feed?.id else { return false }
                return folderFeeds.contains { $0.id == feedId }
            }
        }
    }

    private var articles: [Article] {
        guard !searchText.isEmpty else { return filteredArticles }
        return filteredArticles.filter { SearchService.matches(article: $0, query: searchText) }
    }

    private var navigationTitle: String {
        selection?.title ?? "All Articles"
    }

    var body: some View {
        List(selection: $selectedArticle) {
            ForEach(articles) { article in
                ArticleRow(article: article, searchQuery: searchText)
                    .tag(article as Article?)
            }
        }
        .listStyle(.plain)
        .navigationTitle(navigationTitle)
        .searchable(
            text: $searchText,
            isPresented: $isSearching,
            placement: .automatic,
            prompt: "Search articles"
        )
        .overlay {
            if articles.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if articles.isEmpty {
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
        case .folder:
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
        case .feed, .folder, nil:
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
        case .feed, .folder, nil:
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
    var searchQuery: String = ""
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

            highlightedText(article.title, query: searchQuery)
                .font(.headline)
                .fontWeight(article.isRead ? .regular : .semibold)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .lineLimit(2)

            if let summary = article.summary {
                highlightedText(summary, query: searchQuery)
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
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleReadWithHaptic()
                } label: {
                    Label(
                        article.isRead ? "Unread" : "Read",
                        systemImage: article.isRead ? "circle" : "checkmark.circle"
                    )
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    toggleStarWithHaptic()
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

    #if os(iOS)
        private func toggleReadWithHaptic() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            article.isRead.toggle()
        }

        private func toggleStarWithHaptic() {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            article.isStarred.toggle()
        }
    #endif

    /// 検索クエリにマッチした部分をハイライト表示するテキストを生成
    @ViewBuilder
    private func highlightedText(_ text: String, query: String) -> some View {
        if query.isEmpty {
            Text(text)
        } else {
            let ranges = SearchService.findMatchRanges(in: text, for: query)
            if ranges.isEmpty {
                Text(text)
            } else {
                Text(buildAttributedString(text: text, ranges: ranges))
            }
        }
    }

    /// マッチした範囲をハイライトしたAttributedStringを生成
    private func buildAttributedString(text: String, ranges: [Range<String.Index>])
        -> AttributedString
    {
        var attributedString = AttributedString(text)

        for range in ranges {
            // String.IndexをAttributedString.Indexに変換
            let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: range.upperBound)

            let attrStart = attributedString.index(
                attributedString.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attributedString.index(
                attributedString.startIndex, offsetByCharacters: endOffset)

            let attrRange = attrStart..<attrEnd
            attributedString[attrRange].backgroundColor = .yellow.opacity(0.3)
            attributedString[attrRange].foregroundColor = .primary
        }

        return attributedString
    }
}

#Preview {
    TimelineView(selection: .allUnread, selectedArticle: .constant(nil), onRefresh: nil)
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
