import Foundation

/// Media hanging off a note.
///
/// The bytes never live in the database — only this record does. `relativePath`
/// points into the app's media directory, which keeps the store small and keeps
/// large files out of every query and every backup.
nonisolated struct Attachment: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: AttachmentKind
    /// Path relative to the attachment store's root, e.g. `"audios/6F2A….m4a"`.
    var relativePath: String
    var byteCount: Int
    /// Audio and video only.
    var duration: TimeInterval?
    var createdAt: Date
}

nonisolated enum AttachmentKind: String, Codable, Hashable, Sendable, CaseIterable {
    case image, audio, video, file

    var systemImage: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .file:  return "doc"
        }
    }

    var folderName: String { rawValue + "s" }
}

/// What the UI hands to the repository when adding media. The repository owns
/// writing bytes to disk, so no feature code ever touches the filesystem.
nonisolated struct AttachmentDraft: Sendable {
    enum Source: Sendable {
        case data(Data, fileExtension: String)
        /// A file already on disk — it is *copied* into the store.
        case fileURL(URL)
    }

    var kind: AttachmentKind
    var source: Source
    var duration: TimeInterval?

    init(kind: AttachmentKind, source: Source, duration: TimeInterval? = nil) {
        self.kind = kind
        self.source = source
        self.duration = duration
    }
}
