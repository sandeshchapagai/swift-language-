import Foundation
import SwiftData

/// The one place SwiftData is spoken.
///
/// An `actor` because `ModelContext` is not thread-safe and database work has no
/// business on the main thread once notes carry media. Callers `await`; the UI
/// stays responsive.
actor SwiftDataNoteRepository: NoteRepository {
    nonisolated let changes = AsyncBroadcaster<Void>()

    private let container: ModelContainer
    private let files: AttachmentStore
    private lazy var context = ModelContext(container)

    init(container: ModelContainer, files: AttachmentStore) {
        self.container = container
        self.files = files
    }

    // MARK: Reads

    func summaries(matching query: String) async throws -> [NoteSummary] {
        var descriptor = FetchDescriptor<NoteEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        // Without this SwiftData faults each note's attachments one row at a
        // time while the list scrolls.
        descriptor.relationshipKeyPathsForPrefetching = [\.attachments]

        let all = try context.fetch(descriptor)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all.map { $0.toSummary() } }

        // Filtered here rather than in the predicate: `localizedStandardContains`
        // is not available inside a SwiftData `#Predicate`, and case- and
        // diacritic-insensitive matching is what a search field should do.
        return all
            .filter {
                $0.title.localizedStandardContains(trimmed)
                    || $0.content.localizedStandardContains(trimmed)
            }
            .map { $0.toSummary() }
    }

    func note(id: UUID) async throws -> Note? {
        try entity(id: id)?.toDomain()
    }

    // MARK: Writes

    @discardableResult
    func create(title: String, content: String) async throws -> Note {
        let now = Date.now
        let entity = NoteEntity(title: title, content: content, createdAt: now, updatedAt: now)
        context.insert(entity)
        try commit()
        return entity.toDomain()
    }

    func update(id: UUID, title: String, content: String) async throws {
        guard let entity = try entity(id: id) else { return }
        guard entity.title != title || entity.content != content else { return }

        entity.title = title
        entity.content = content
        entity.updatedAt = .now
        try commit()
    }

    func delete(id: UUID) async throws {
        guard let entity = try entity(id: id) else { return }

        // Files first: the cascade delete takes the attachment rows with it, and
        // once those are gone nothing remembers which files to clean up.
        let orphaned = (entity.attachments ?? []).map(\.relativePath)
        context.delete(entity)
        try commit()

        for path in orphaned {
            try? await files.remove(relativePath: path)
        }
    }

    // MARK: Attachments

    @discardableResult
    func addAttachment(_ draft: AttachmentDraft, to noteID: UUID) async throws -> Attachment {
        guard let note = try entity(id: noteID) else {
            throw RepositoryError.noteNotFound(noteID)
        }

        // Bytes hit disk first. If the write fails there is no dangling row, and
        // if the insert fails the worst case is one orphaned file.
        let stored = try await files.store(draft.source, kind: draft.kind)

        let attachment = AttachmentEntity(kind: draft.kind,
                                          relativePath: stored.relativePath,
                                          byteCount: stored.byteCount,
                                          duration: draft.duration)
        attachment.note = note
        context.insert(attachment)
        note.updatedAt = .now
        try commit()

        return attachment.toDomain()
    }

    func removeAttachment(id: UUID) async throws {
        let descriptor = FetchDescriptor<AttachmentEntity>(predicate: #Predicate { $0.id == id })
        guard let attachment = try context.fetch(descriptor).first else { return }

        let path = attachment.relativePath
        attachment.note?.updatedAt = .now
        context.delete(attachment)
        try commit()

        try? await files.remove(relativePath: path)
    }

    // MARK: Plumbing

    private func entity(id: UUID) throws -> NoteEntity? {
        var descriptor = FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Save, then tell everyone. Every mutation goes through here so no path can
    /// forget to notify.
    private func commit() throws {
        guard context.hasChanges else { return }
        try context.save()
        changes.send()
    }
}

nonisolated enum RepositoryError: LocalizedError {
    case noteNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .noteNotFound: return "That note no longer exists."
        }
    }
}
