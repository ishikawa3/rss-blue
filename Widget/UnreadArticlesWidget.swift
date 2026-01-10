import SwiftUI
import WidgetKit

/// Timeline entry for the unread articles widget
struct UnreadArticlesEntry: TimelineEntry {
    let date: Date
    let unreadCount: Int
    let articles: [WidgetArticle]
    let configuration: ConfigurationAppIntent

    static let placeholder = UnreadArticlesEntry(
        date: Date(),
        unreadCount: 5,
        articles: [
            WidgetArticle(
                id: "1", title: "Sample Article Title", feedTitle: "Tech News",
                publishedDate: Date(), isRead: false),
            WidgetArticle(
                id: "2", title: "Another Article Here", feedTitle: "Design Blog",
                publishedDate: Date().addingTimeInterval(-3600), isRead: false),
            WidgetArticle(
                id: "3", title: "Third Article Example", feedTitle: "Swift Weekly",
                publishedDate: Date().addingTimeInterval(-7200), isRead: false),
        ],
        configuration: ConfigurationAppIntent()
    )
}

/// App Intent for widget configuration
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Configure the RSS Blue widget.")

    @Parameter(title: "Show Feed Name", default: true)
    var showFeedName: Bool
}

/// Timeline provider for the widget
struct UnreadArticlesProvider: AppIntentTimelineProvider {
    typealias Entry = UnreadArticlesEntry
    typealias Intent = ConfigurationAppIntent

    func placeholder(in context: Context) -> UnreadArticlesEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async
        -> UnreadArticlesEntry
    {
        let data = WidgetDataManager.shared.loadWidgetData()
        return UnreadArticlesEntry(
            date: Date(),
            unreadCount: data.unreadCount,
            articles: Array(data.recentArticles.prefix(maxArticles(for: context.family))),
            configuration: configuration
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
        UnreadArticlesEntry
    > {
        let data = WidgetDataManager.shared.loadWidgetData()

        let entry = UnreadArticlesEntry(
            date: Date(),
            unreadCount: data.unreadCount,
            articles: Array(data.recentArticles.prefix(maxArticles(for: context.family))),
            configuration: configuration
        )

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func maxArticles(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 3
        case .systemLarge:
            return 6
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return 1
        @unknown default:
            return 3
        }
    }
}

/// Main widget definition
struct UnreadArticlesWidget: Widget {
    let kind: String = "UnreadArticlesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: UnreadArticlesProvider()
        ) { entry in
            UnreadArticlesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Unread Articles")
        .description("View your unread RSS articles.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// MARK: - Widget Views

struct UnreadArticlesWidgetView: View {
    let entry: UnreadArticlesEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: UnreadArticlesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.blue)
                Text("RSS Blue")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            if entry.unreadCount > 0 {
                Text("\(entry.unreadCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("unread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)

                Text("All caught up!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "rssblue://unread"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: UnreadArticlesEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left side - count
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .foregroundStyle(.blue)
                    Text("RSS Blue")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                if entry.unreadCount > 0 {
                    Text("\(entry.unreadCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("unread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)

                    Text("All caught up!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80)

            Divider()

            // Right side - articles
            VStack(alignment: .leading, spacing: 6) {
                if entry.articles.isEmpty {
                    Text("No unread articles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(entry.articles) { article in
                        Link(destination: URL(string: "rssblue://article/\(article.id)")!) {
                            ArticleRowView(
                                article: article, showFeedName: entry.configuration.showFeedName)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: UnreadArticlesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.blue)
                Text("RSS Blue")
                    .font(.headline)

                Spacer()

                if entry.unreadCount > 0 {
                    Text("\(entry.unreadCount) unread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            Divider()

            // Articles
            if entry.articles.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.articles) { article in
                    Link(destination: URL(string: "rssblue://article/\(article.id)")!) {
                        LargeArticleRowView(
                            article: article, showFeedName: entry.configuration.showFeedName)
                    }
                    if article.id != entry.articles.last?.id {
                        Divider()
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Accessory Rectangular (Lock Screen)

struct AccessoryRectangularView: View {
    let entry: UnreadArticlesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "dot.radiowaves.up.forward")
                Text("RSS Blue")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(entry.unreadCount)")
                    .fontWeight(.bold)
            }
            .font(.caption)

            if let article = entry.articles.first {
                Text(article.title)
                    .font(.caption2)
                    .lineLimit(2)
            } else {
                Text("No unread articles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "rssblue://unread"))
    }
}

// MARK: - Article Row Views

struct ArticleRowView: View {
    let article: WidgetArticle
    let showFeedName: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(article.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if showFeedName {
                Text(article.feedTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct LargeArticleRowView: View {
    let article: WidgetArticle
    let showFeedName: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if showFeedName {
                        Text(article.feedTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let date = article.publishedDate {
                        if showFeedName {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    UnreadArticlesWidget()
} timeline: {
    UnreadArticlesEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    UnreadArticlesWidget()
} timeline: {
    UnreadArticlesEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    UnreadArticlesWidget()
} timeline: {
    UnreadArticlesEntry.placeholder
}
