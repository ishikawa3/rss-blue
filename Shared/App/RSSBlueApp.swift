import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
    import BackgroundTasks
#endif

@main
struct RSSBlueApp: App {
    let modelContainer: ModelContainer
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var exportData: Data?
    @State private var importResult: FeedService.OPMLImportResult?
    @State private var showImportResult = false
    @State private var importError: String?
    @State private var showImportError = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let config: ModelConfiguration

            // Check if running in test environment
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                // Use in-memory store for tests
                config = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                // TODO: Re-enable CloudKit after setting up Apple Developer account
                // config = ModelConfiguration(
                //     cloudKitDatabase: .private("iCloud.com.ishikawa.rssblue")
                // )

                // Use local storage for now
                config = ModelConfiguration()
            }

            modelContainer = try ModelContainer(
                for: Feed.self, Article.self, Folder.self,
                configurations: config
            )

            // Set up background refresh service
            BackgroundRefreshService.shared.modelContainer = modelContainer

            #if os(iOS)
                // Register background task for iOS
                BackgroundRefreshService.shared.registerBackgroundTask()
            #endif
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fileImporter(
                    isPresented: $showImportPicker,
                    allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml, .xml],
                    allowsMultipleSelection: false
                ) { result in
                    handleImport(result: result)
                }
                .fileExporter(
                    isPresented: $showExportPicker,
                    document: exportData.map { OPMLFileDocument(data: $0) },
                    contentType: UTType(filenameExtension: "opml") ?? .xml,
                    defaultFilename: "RSS Blue Subscriptions.opml"
                ) { result in
                    // Export completed
                    exportData = nil
                }
                .alert("Import Complete", isPresented: $showImportResult) {
                    Button("OK") { showImportResult = false }
                } message: {
                    if let result = importResult {
                        Text(
                            "Imported: \(result.imported)\nSkipped (duplicates): \(result.skipped)\nFailed: \(result.failed)"
                        )
                    }
                }
                .alert("Import Error", isPresented: $showImportError) {
                    Button("OK") { showImportError = false }
                } message: {
                    Text(importError ?? "Failed to import OPML")
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
            .commands {
                // Article commands
                ArticleCommands()

                // Go commands
                GoCommands()

                // Subscription commands
                SubscriptionCommands()

                // Import/Export commands
                CommandGroup(after: .importExport) {
                    Button("Import OPML...") {
                        showImportPicker = true
                    }
                    .keyboardShortcut("i", modifiers: [.command, .shift])

                    Button("Export OPML...") {
                        exportOPML()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                }
            }
        #endif

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }

    @MainActor
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Cannot access the file"
                        showImportError = true
                        return
                    }

                    defer { url.stopAccessingSecurityScopedResource() }

                    let feedService = FeedService(modelContext: modelContainer.mainContext)
                    importResult = try await feedService.importOPML(fileURL: url)
                    showImportResult = true
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    @MainActor
    private func exportOPML() {
        do {
            let feedService = FeedService(modelContext: modelContainer.mainContext)
            exportData = try feedService.exportOPML()
            showExportPicker = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    @MainActor
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            #if os(macOS)
                // Start periodic refresh on macOS when app becomes active
                BackgroundRefreshService.shared.startPeriodicRefresh()
            #endif

        case .background:
            #if os(iOS)
                // Schedule background refresh when going to background on iOS
                BackgroundRefreshService.shared.scheduleBackgroundRefresh()
            #endif

        case .inactive:
            break

        @unknown default:
            break
        }
    }
}

// MARK: - OPML File Document for Export

struct OPMLFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "opml") ?? .xml, .xml]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
