import Foundation
import SwiftData

/// Service for managing folder operations
@MainActor
final class FolderService: ObservableObject {
    private let modelContext: ModelContext

    @Published var isLoading = false
    @Published var error: FolderServiceError?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// Creates a new folder
    /// - Parameters:
    ///   - name: The folder name
    ///   - sortOrder: Optional sort order (defaults to end of list)
    /// - Returns: The created folder
    @discardableResult
    func createFolder(name: String, sortOrder: Int? = nil) throws -> Folder {
        let order = sortOrder ?? getNextSortOrder()
        let folder = Folder(name: name, sortOrder: order)
        modelContext.insert(folder)
        try modelContext.save()
        return folder
    }

    // MARK: - Read

    /// Fetches all folders sorted by sortOrder
    func fetchAllFolders() throws -> [Folder] {
        let descriptor = FetchDescriptor<Folder>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches feeds that are not in any folder
    func fetchUncategorizedFeeds() throws -> [Feed] {
        let descriptor = FetchDescriptor<Feed>(
            predicate: #Predicate<Feed> { feed in
                feed.folder == nil
            },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.title)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Update

    /// Renames a folder
    func renameFolder(_ folder: Folder, to newName: String) throws {
        folder.name = newName
        try modelContext.save()
    }

    /// Moves a feed to a folder
    func moveFeed(_ feed: Feed, to folder: Folder?) throws {
        feed.folder = folder
        try modelContext.save()
    }

    /// Moves multiple feeds to a folder
    func moveFeeds(_ feeds: [Feed], to folder: Folder?) throws {
        for feed in feeds {
            feed.folder = folder
        }
        try modelContext.save()
    }

    /// Toggles folder expansion state
    func toggleFolderExpansion(_ folder: Folder) throws {
        folder.isExpanded.toggle()
        try modelContext.save()
    }

    /// Reorders folders
    func reorderFolders(_ folders: [Folder]) throws {
        for (index, folder) in folders.enumerated() {
            folder.sortOrder = index
        }
        try modelContext.save()
    }

    /// Reorders feeds within a folder or in uncategorized
    func reorderFeeds(_ feeds: [Feed]) throws {
        for (index, feed) in feeds.enumerated() {
            feed.sortOrder = index
        }
        try modelContext.save()
    }

    // MARK: - Delete

    /// Deletes a folder (feeds are moved to uncategorized, not deleted)
    func deleteFolder(_ folder: Folder) throws {
        // Feeds will be automatically set to nil folder due to nullify delete rule
        modelContext.delete(folder)
        try modelContext.save()
    }

    // MARK: - Helpers

    private func getNextSortOrder() -> Int {
        do {
            let folders = try fetchAllFolders()
            return (folders.map(\.sortOrder).max() ?? -1) + 1
        } catch {
            return 0
        }
    }
}

// MARK: - Errors

enum FolderServiceError: LocalizedError {
    case saveFailed(String)
    case folderNotFound
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .folderNotFound:
            return "Folder not found"
        case .duplicateName:
            return "A folder with this name already exists"
        }
    }
}
