import Foundation
import Observation

/// State for one note being edited.
///
/// Creating and editing are the same screen because they are the same operation
/// against the repository — the only difference is whether a row exists yet.
@MainActor
@Observable
final class NoteEditorModel {
    enum Mode: Hashable {
        case create
        case edit(UUID)
    }

    var title: String = ""
    var content: String = ""
    private(set) var attachments: [Attachment] = []
    private(set) var isBusy = false
    var errorMessage: String?

    private let repository: NoteRepository
    private let mode: Mode
    /// Assigned as soon as the note exists, so attachments added during a first
    /// edit have somewhere to attach to.
    private var noteID: UUID?

    init(repository: NoteRepository, mode: Mode) {
        self.repository = repository
        self.mode = mode
        if case .edit(let id) = mode { noteID = id }
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty
    }

    var navigationTitle: String { noteID == nil ? "New Note" : "Edit Note" }

    func load() async {
        guard let noteID else { return }
        do {
            guard let note = try await repository.note(id: noteID) else { return }
            title = note.title
            content = note.content
            attachments = note.attachments
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save() async -> Bool {
        guard canSave else { return false }
        isBusy = true
        defer { isBusy = false }

        do {
            if let noteID {
                try await repository.update(id: noteID, title: title, content: content)
            } else {
                let created = try await repository.create(title: title, content: content)
                noteID = created.id
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addAttachment(_ draft: AttachmentDraft) async {
        isBusy = true
        defer { isBusy = false }

        do {
            // A draft note has no row yet; make one so the media has an owner.
            let ownerID = try await resolvedNoteID()
            let attachment = try await repository.addAttachment(draft, to: ownerID)
            attachments.append(attachment)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAttachment(_ attachment: Attachment) async {
        attachments.removeAll { $0.id == attachment.id }
        do {
            try await repository.removeAttachment(id: attachment.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func resolvedNoteID() async throws -> UUID {
        if let noteID { return noteID }
        let created = try await repository.create(title: title, content: content)
        noteID = created.id
        return created.id
    }
}
