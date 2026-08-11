import Foundation

/// Entity → domain. One direction only, and only here.
///
/// Mapping costs a little typing and buys the thing that matters: a `@Model`
/// object is a live, context-bound reference type. Handing one to a view means
/// the view can mutate the database by assigning to a property, and it faults
/// the object graph while scrolling. Views get frozen structs instead.
nonisolated extension AttachmentEntity {
    func toDomain() -> Attachment {
        Attachment(id: id,
                   kind: kind,
                   relativePath: relativePath,
                   byteCount: byteCount,
                   duration: duration > 0 ? duration : nil,
                   createdAt: createdAt)
    }
}

nonisolated extension NoteEntity {
    func toDomain() -> Note {
        Note(id: id,
             title: title,
             content: content,
             createdAt: createdAt,
             updatedAt: updatedAt,
             attachments: sortedAttachments.map { $0.toDomain() })
    }

    /// Reads the attachment relationship for a count and nothing more — the
    /// point of having a separate summary type.
    func toSummary() -> NoteSummary {
        let media = attachments ?? []
        return NoteSummary(id: id,
                           title: title,
                           snippet: Self.snippet(from: content),
                           updatedAt: updatedAt,
                           attachmentCount: media.count,
                           attachmentKinds: Set(media.map(\.kind)))
    }

    private static func snippet(from content: String, limit: Int = 120) -> String {
        let flattened = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > limit else { return flattened }
        return String(flattened.prefix(limit)) + "…"
    }
}
