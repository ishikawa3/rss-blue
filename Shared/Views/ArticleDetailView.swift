import SwiftUI
import WebKit

struct ArticleDetailView: View {
    let article: Article?
    @Environment(\.modelContext) private var modelContext
    @State private var showFullContent: Bool = true
    @State private var isFetchingContent: Bool = false
    @State private var fetchError: String?

    var body: some View {
        Group {
            if let article = article {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(article.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .textSelection(.enabled)

                            HStack(spacing: 12) {
                                if let feedTitle = article.feed?.title {
                                    Label(feedTitle, systemImage: "dot.radiowaves.up.forward")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let author = article.author {
                                    Label(author, systemImage: "person")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let date = article.publishedDate {
                                    Label {
                                        Text(date, style: .date)
                                    } icon: {
                                        Image(systemName: "calendar")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }

                        // Action buttons
                        HStack(spacing: 16) {
                            Button(action: { toggleRead(article) }) {
                                Label(
                                    article.isRead ? "Mark as Unread" : "Mark as Read",
                                    systemImage: article.isRead ? "circle" : "checkmark.circle.fill"
                                )
                            }
                            .buttonStyle(.bordered)

                            Button(action: { toggleStar(article) }) {
                                Label(
                                    article.isStarred ? "Unstar" : "Star",
                                    systemImage: article.isStarred ? "star.fill" : "star"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(article.isStarred ? .yellow : nil)

                            Spacer()

                            if let url = article.url {
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        // Content view toggle
                        if article.hasFullContent || hasOriginalContent(article) {
                            contentViewToggle(article: article)
                        }

                        Divider()

                        // Content
                        contentView(for: article)

                        // Fetch full content button (when not already fetched)
                        if !article.hasFullContent && article.url != nil {
                            fetchFullContentButton(for: article)
                        }

                        // Error display
                        if let error = fetchError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        // Open in Browser
                        if let url = article.url {
                            Divider()

                            Link(destination: url) {
                                Label("Open in Browser", systemImage: "safari")
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Mark as read when viewing
                    if !article.isRead {
                        article.isRead = true
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Article Selected",
                    systemImage: "doc.text",
                    description: Text("Select an article to read")
                )
            }
        }
        .navigationTitle(article?.title ?? "Article")
        #if os(macOS)
            .navigationSubtitle(article?.feed?.title ?? "")
        #endif
    }

    // MARK: - Content View Components

    @ViewBuilder
    private func contentViewToggle(article: Article) -> some View {
        if article.hasFullContent && hasOriginalContent(article) {
            Picker("Content View", selection: $showFullContent) {
                Text("Full Article").tag(true)
                Text("Summary").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func contentView(for article: Article) -> some View {
        if showFullContent && article.hasFullContent, let fullContent = article.fullContent {
            HTMLTextView(html: fullContent)
                .textSelection(.enabled)
        } else if let content = article.contentHTML {
            HTMLTextView(html: content)
                .textSelection(.enabled)
        } else if let summary = article.summary {
            Text(summary)
                .font(.body)
                .textSelection(.enabled)
        } else {
            Text("No content available")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fetchFullContentButton(for article: Article) -> some View {
        Button(action: {
            Task {
                await fetchFullContent(for: article)
            }
        }) {
            HStack {
                if isFetchingContent {
                    ProgressView()
                        .controlSize(.small)
                }
                Label(
                    isFetchingContent ? "Fetching..." : "Fetch Full Article",
                    systemImage: "arrow.down.doc"
                )
            }
        }
        .buttonStyle(.bordered)
        .disabled(isFetchingContent)
    }

    // MARK: - Helper Methods

    private func hasOriginalContent(_ article: Article) -> Bool {
        return article.contentHTML != nil || article.summary != nil
    }

    private func toggleRead(_ article: Article) {
        article.isRead.toggle()
    }

    private func toggleStar(_ article: Article) {
        article.isStarred.toggle()
    }

    @MainActor
    private func fetchFullContent(for article: Article) async {
        guard let url = article.url else { return }

        isFetchingContent = true
        fetchError = nil

        let contentExtractor = ContentExtractorService()

        do {
            let extracted = try await contentExtractor.extractContent(from: url)
            article.fullContent = extracted.content
            article.hasFullContent = true

            // Update author if not set and extracted
            if article.author == nil, let author = extracted.author {
                article.author = author
            }

            showFullContent = true
        } catch {
            fetchError = "Failed to fetch full content: \(error.localizedDescription)"
        }

        isFetchingContent = false
    }
}

// Simple HTML text renderer
struct HTMLTextView: View {
    let html: String

    var body: some View {
        // For now, strip HTML tags and show plain text
        // TODO: Implement proper HTML rendering with AttributedString
        Text(html.strippingHTMLTags())
            .font(.body)
            .lineSpacing(4)
    }
}

#Preview {
    ArticleDetailView(article: nil)
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
