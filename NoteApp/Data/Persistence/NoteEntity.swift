import Foundation
import SwiftData

/// Storage shape for a note. Lives and dies inside `Data/Persistence` — nothing
/// outside this folder imports it.
@Model
final class NoteEntity {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    /// Cascade: deleting a note deletes its attachment rows. The *files* are
    /// removed by the repository, which is the only thing that knows about disk.
    @Relationship(deleteRule: .cascade, inverse: \AttachmentEntity.note)
    var attachments: [AttachmentEntity]? = []

    init(id: UUID = UUID(),
         title: String = "",
         content: String = "",
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachments = []
    }

    var sortedAttachments: [AttachmentEntity] {
        (attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}
