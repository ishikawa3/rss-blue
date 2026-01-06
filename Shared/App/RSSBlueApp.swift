import SwiftUI
import SwiftData

@main
struct RSSBlueApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .private("iCloud.com.ishikawa.rssblue")
            )
            
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
