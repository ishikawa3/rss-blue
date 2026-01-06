import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Int = 30
    @AppStorage("showUnreadOnly") private var showUnreadOnly: Bool = false
    @Environment(\.modelContext) private var modelContext

    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var exportData: Data?
    @State private var importResult: FeedService.OPMLImportResult?
    @State private var showImportResult = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var isImporting = false

    var body: some View {
        Form {
            Section("General") {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("Manual only").tag(0)
                }

                Toggle("Show Unread Only", isOn: $showUnreadOnly)
            }

            Section("Import & Export") {
                Button {
                    showImportPicker = true
                } label: {
                    HStack {
                        Label("Import OPML", systemImage: "square.and.arrow.down")
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isImporting)

                Button {
                    exportOPML()
                } label: {
                    Label("Export OPML", systemImage: "square.and.arrow.up")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 200)
            .padding()
        #endif
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

    @MainActor
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            isImporting = true

            Task {
                defer { isImporting = false }

                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Cannot access the file"
                        showImportError = true
                        return
                    }

                    defer { url.stopAccessingSecurityScopedResource() }

                    let feedService = FeedService(modelContext: modelContext)
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
            let feedService = FeedService(modelContext: modelContext)
            exportData = try feedService.exportOPML()
            showExportPicker = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }
}

#Preview {
    SettingsView()
}
