import Foundation
import SwiftData

/// Metadata only. The media itself sits on disk under `relativePath`.
@Model
final class AttachmentEntity {
    var id: UUID = UUID()
    var kindRaw: String = AttachmentKind.file.rawValue
    var relativePath: String = ""
    var byteCount: Int = 0
    /// Seconds; `0` means "not applicable" (images, documents).
    var duration: Double = 0
    var createdAt: Date = Date.distantPast

    var note: NoteEntity?

    init(id: UUID = UUID(),
         kind: AttachmentKind,
         relativePath: String,
         byteCount: Int,
         duration: TimeInterval? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.duration = duration ?? 0
        self.createdAt = createdAt
    }

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .file }
        set { kindRaw = newValue.rawValue }
    }
}
