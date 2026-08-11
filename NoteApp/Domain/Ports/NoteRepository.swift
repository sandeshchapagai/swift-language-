import Foundation

/// The only door the UI has to note data.
///
/// Views and view models depend on this protocol, never on SwiftData. That is
/// what makes the storage engine replaceable and the feature layer testable
/// with a hand-written fake.
nonisolated protocol NoteRepository: Sendable {
    /// Fires after any mutation, whoever caused it. Screens redraw from this
    /// rather than each guessing when their data went stale.
    var changes: AsyncBroadcaster<Void> { get }

    func summaries(matching query: String) async throws -> [NoteSummary]
    func note(id: UUID) async throws -> Note?

    @discardableResult
    func create(title: String, content: String) async throws -> Note
    func update(id: UUID, title: String, content: String) async throws
    /// Removes the note and every file its attachments own.
    func delete(id: UUID) async throws

    @discardableResult
    func addAttachment(_ draft: AttachmentDraft, to noteID: UUID) async throws -> Attachment
    func removeAttachment(id: UUID) async throws
}
