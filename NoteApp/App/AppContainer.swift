import Foundation
import SwiftUI

/// Composition root: the single place concrete types are chosen.
///
/// Everything else depends on protocols, so this is the only file that has to
/// change to swap the storage engine or hand the feature layer a fake.
@Observable
final class AppContainer {
    let notes: NoteRepository
    let attachments: AttachmentStore

    init(notes: NoteRepository, attachments: AttachmentStore) {
        self.notes = notes
        self.attachments = attachments
    }

    static func live() throws -> AppContainer {
        let attachments = try FileAttachmentStore()
        let container = try PersistenceStack.container()
        return AppContainer(
            notes: SwiftDataNoteRepository(container: container, files: attachments),
            attachments: attachments
        )
    }

    /// In-memory store plus a scratch media directory — for previews and tests.
    static func ephemeral() throws -> AppContainer {
        let mediaRoot = URL.temporaryDirectory.appending(path: "NotePreview-\(UUID().uuidString)")
        let attachments = try FileAttachmentStore(root: mediaRoot)
        let container = try PersistenceStack.container(inMemory: true)
        return AppContainer(
            notes: SwiftDataNoteRepository(container: container, files: attachments),
            attachments: attachments
        )
    }
}
