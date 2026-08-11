import Foundation

/// A note as the rest of the app understands it.
///
/// Deliberately a plain value type: no SwiftData, no UIKit. The persistence
/// layer maps *to* this, never the other way around, so replacing the store
/// never reaches the UI.
nonisolated struct Note: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var attachments: [Attachment]

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
    }
}

/// The lightweight projection the list screen renders.
///
/// Loading full notes — and therefore every attachment relationship — just to
/// draw a list is the usual reason note apps get slow once media lands.
nonisolated struct NoteSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var snippet: String
    var updatedAt: Date
    var attachmentCount: Int
    var attachmentKinds: Set<AttachmentKind>

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
    }
}
