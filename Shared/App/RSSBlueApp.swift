import SwiftData
import SwiftUI

@main
struct RSSBlueApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let config: ModelConfiguration

            // Check if running in test environment
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                // Use in-memory store for tests
                config = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                // Use CloudKit for production
                config = ModelConfiguration(
                    cloudKitDatabase: .private("iCloud.com.ishikawa.rssblue")
                )
            }

            modelContainer = try ModelContainer(
                for: Feed.self, Article.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }
}
