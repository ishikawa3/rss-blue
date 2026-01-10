import SwiftData
import SwiftUI

/// Menu bar icon label with unread count badge
struct MenuBarLabel: View {
    @Query(filter: #Predicate<Article> { !$0.isRead }) private var unreadArticles: [Article]

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)

            if unreadArticles.count > 0 {
                Text(formattedCount)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }

    private var iconName: String {
        unreadArticles.isEmpty ? "dot.radiowaves.up.forward" : "dot.radiowaves.up.forward"
    }

    private var formattedCount: String {
        if unreadArticles.count > 999 {
            return "999+"
        }
        return "\(unreadArticles.count)"
    }
}

#Preview {
    MenuBarLabel()
        .modelContainer(for: [Feed.self, Article.self, Folder.self], inMemory: true)
}
