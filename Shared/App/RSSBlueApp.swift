import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
        }
        .modelContainer(modelContainer)
        #if os(macOS)
            .commands {
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
