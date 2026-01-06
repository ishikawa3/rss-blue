import SwiftUI
import WebKit

struct ArticleDetailView: View {
  let article: Article?

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

            Divider()

            // Content
            if let content = article.contentHTML {
              HTMLTextView(html: content)
                .textSelection(.enabled)
            } else if let summary = article.summary {
              Text(summary)
                .font(.body)
                .textSelection(.enabled)
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

  private func toggleRead(_ article: Article) {
    article.isRead.toggle()
  }

  private func toggleStar(_ article: Article) {
    article.isStarred.toggle()
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
