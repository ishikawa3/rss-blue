import SwiftData
import SwiftUI

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var urlText = ""
    @State private var isValidating = false
    @State private var isAdding = false
    @State private var validationResult: ParsedFeed?
    @State private var errorMessage: String?
    @State private var showError = false

    private var feedService: FeedService {
        FeedService(modelContext: modelContext)
    }

    private var isValidURL: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var normalized = trimmed
        if !normalized.lowercased().hasPrefix("http://")
            && !normalized.lowercased().hasPrefix("https://")
        {
            normalized = "https://" + normalized
        }

        guard let url = URL(string: normalized),
            let host = url.host,
            !host.isEmpty
        else {
            return false
        }

        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Feed URL", text: $urlText, prompt: Text("https://example.com/feed.xml")
                    )
                    .textContentType(.URL)
                    #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onChange(of: urlText) { _, _ in
                        // Reset validation when URL changes
                        validationResult = nil
                        errorMessage = nil
                    }

                    if isValidating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Validating feed...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Feed URL")
                } footer: {
                    Text("Enter the URL of an RSS, Atom, or JSON feed")
                        .foregroundStyle(.secondary)
                }

                if let result = validationResult {
                    Section("Feed Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "dot.radiowaves.up.forward")
                                    .foregroundStyle(.blue)
                                Text(result.title)
                                    .font(.headline)
                            }

                            if let description = result.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Text("\(result.articles.count) articles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Feed")
            #if os(macOS)
                .frame(minWidth: 400, idealWidth: 450, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if validationResult != nil {
                        Button("Add") {
                            addFeed()
                        }
                        .disabled(isAdding)
                    } else {
                        Button("Validate") {
                            validateFeed()
                        }
                        .disabled(!isValidURL || isValidating)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .interactiveDismissDisabled(isValidating || isAdding)
        }
    }

    private func validateFeed() {
        guard isValidURL else { return }

        isValidating = true
        errorMessage = nil

        Task {
            do {
                let result = try await feedService.validateFeed(urlString: urlText)
                validationResult = result
            } catch let error as FeedServiceError {
                errorMessage = error.localizedDescription
                if let suggestion = error.recoverySuggestion {
                    errorMessage! += "\n\n" + suggestion
                }
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isValidating = false
        }
    }

    private func addFeed() {
        isAdding = true
        errorMessage = nil

        Task {
            do {
                _ = try await feedService.addFeed(from: urlText)
                dismiss()
            } catch let error as FeedServiceError {
                errorMessage = error.localizedDescription
                if let suggestion = error.recoverySuggestion {
                    errorMessage! += "\n\n" + suggestion
                }
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isAdding = false
        }
    }
}

#Preview {
    AddFeedView()
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
