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

              HStack {
                if let feedTitle = article.feed?.title {
                  Text(feedTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let date = article.publishedDate {
                  Text("•")
                    .foregroundStyle(.secondary)
                  Text(date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { toggleStar(article) }) {
                  Image(systemName: article.isStarred ? "star.fill" : "star")
                    .foregroundStyle(article.isStarred ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
              }
            }

            Divider()

            // Content
            if let content = article.contentHTML {
              HTMLTextView(html: content)
            } else if let summary = article.summary {
              Text(summary)
                .font(.body)
            }

            // Open in Browser
            if let url = article.url {
              Link(destination: url) {
                Label("Open in Browser", systemImage: "safari")
              }
              .padding(.top)
            }
          }
          .padding()
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

  private func toggleStar(_ article: Article) {
    article.isStarred.toggle()
  }
}

// Simple HTML text renderer
struct HTMLTextView: View {
  let html: String

  var body: some View {
    // For now, strip HTML tags and show plain text
    // TODO: Implement proper HTML rendering
    Text(html.strippingHTMLTags())
      .font(.body)
  }
}

#Preview {
  ArticleDetailView(article: nil)
}
