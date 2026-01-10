import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Int = 30
    @AppStorage("refreshOnWiFiOnly") private var refreshOnWiFiOnly: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("showUnreadOnly") private var showUnreadOnly: Bool = false
    @Environment(\.modelContext) private var modelContext

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
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
                .onChange(of: refreshInterval) { _, _ in
                    rescheduleBackgroundRefresh()
                }

                #if os(iOS)
                    Toggle("Refresh on Wi-Fi Only", isOn: $refreshOnWiFiOnly)
                        .disabled(refreshInterval == 0)
                #endif

                Toggle("Show Unread Only", isOn: $showUnreadOnly)
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .disabled(notificationStatus == .denied)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue && notificationStatus == .notDetermined {
                            Task {
                                _ = await NotificationService.shared.requestAuthorization()
                                await updateNotificationStatus()
                            }
                        }
                    }

                if notificationStatus == .denied {
                    Text("Notifications are disabled in System Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .task {
            await updateNotificationStatus()
        }
    }

    @MainActor
    private func updateNotificationStatus() async {
        notificationStatus = await NotificationService.shared.checkAuthorizationStatus()
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

    @MainActor
    private func rescheduleBackgroundRefresh() {
        #if os(iOS)
            BackgroundRefreshService.shared.scheduleBackgroundRefresh()
        #elseif os(macOS)
            BackgroundRefreshService.shared.startPeriodicRefresh()
        #endif
    }
}

#Preview {
    SettingsView()
}
