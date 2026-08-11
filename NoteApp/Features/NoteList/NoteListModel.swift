import Foundation
import Observation

/// State for the list screen. Holds no SwiftUI types, so it can be driven from a
/// test without a view.
@MainActor
@Observable
final class NoteListModel {
    private(set) var summaries: [NoteSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            searchTask?.cancel()
            searchTask = Task { [weak self] in
                // Debounce so a fetch does not fire per keystroke.
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await self?.load()
            }
        }
    }

    private let repository: NoteRepository
    private var searchTask: Task<Void, Never>?

    init(repository: NoteRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = summaries.isEmpty
        defer { isLoading = false }
        do {
            summaries = try await repository.summaries(matching: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Redraws on any mutation, including ones this screen did not cause — such
    /// as the editor saving or attaching media.
    func observeChanges() async {
        for await _ in repository.changes.stream() {
            await load()
        }
    }

    func delete(_ summary: NoteSummary) async {
        // Optimistic: drop it now, let the change broadcast confirm.
        summaries.removeAll { $0.id == summary.id }
        do {
            try await repository.delete(id: summary.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func delete(at offsets: IndexSet) async {
        for summary in offsets.map({ summaries[$0] }) {
            await delete(summary)
        }
    }
}
