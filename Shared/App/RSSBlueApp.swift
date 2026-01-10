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
    @State private var pendingArticleId: String?
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

            // Set up notification service
            setupNotificationService()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    private func setupNotificationService() {
        // Handle notification tap
        NotificationService.shared.onNotificationTapped = { articleId in
            Task { @MainActor in
                self.pendingArticleId = articleId
            }
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
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
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .task {
                    // Request notification permission on first launch
                    await requestNotificationPermissionIfNeeded()
                }
                .environment(\.pendingArticleId, $pendingArticleId)
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

            MenuBarExtra {
                MenuBarView()
                    .modelContainer(modelContainer)
            } label: {
                MenuBarLabel()
                    .modelContainer(modelContainer)
            }
            .menuBarExtraStyle(.window)
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

    @MainActor
    private func requestNotificationPermissionIfNeeded() async {
        let status = await NotificationService.shared.checkAuthorizationStatus()

        if status == .notDetermined {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    /// Handle deep links from widgets and other sources
    /// URL format: rssblue://article/{articleId} or rssblue://unread
    @MainActor
    private func handleDeepLink(url: URL) {
        guard url.scheme == "rssblue" else { return }

        switch url.host {
        case "article":
            // Extract article ID from path
            let articleId = url.pathComponents.dropFirst().first
            if let articleId = articleId {
                pendingArticleId = articleId
            }
        case "unread":
            // Just open the app to the unread view
            // The default view is already unread articles
            break
        default:
            break
        }
    }
}

// MARK: - Environment Keys

private struct PendingArticleIdKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

extension EnvironmentValues {
    var pendingArticleId: Binding<String?> {
        get { self[PendingArticleIdKey.self] }
        set { self[PendingArticleIdKey.self] = newValue }
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
