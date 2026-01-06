import SwiftUI
import SwiftData

struct TimelineView: View {
    let feed: Feed?
    @Binding var selectedArticle: Article?
    @Query(sort: \Article.publishedDate, order: .reverse) private var allArticles: [Article]
    
    private var articles: [Article] {
        if let feed = feed {
            return allArticles.filter { $0.feed == feed }
        }
        return allArticles
    }
    
    var body: some View {
        List(selection: $selectedArticle) {
            ForEach(articles) { article in
                ArticleRow(article: article)
                    .tag(article as Article?)
            }
        }
        .listStyle(.plain)
        .navigationTitle(feed?.title ?? "All Articles")
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView(
                    "No Articles",
                    systemImage: "newspaper",
                    description: Text("Add a feed to get started")
                )
            }
        }
        #if os(iOS)
        .refreshable {
            // TODO: Implement refresh
        }
        #endif
    }
}

struct ArticleRow: View {
    let article: Article
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
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
                .fontWeight(article.isRead ? .regular : .bold)
                .lineLimit(2)
            
            if let summary = article.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if article.isStarred {
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
    }
}

#Preview {
    TimelineView(feed: nil, selectedArticle: .constant(nil))
        .modelContainer(for: Article.self, inMemory: true)
}
