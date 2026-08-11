import Foundation

/// Blob storage for media. Separate from the database on purpose: audio and
/// video get large, and rows that big make every query slow and every backup
/// enormous.
nonisolated protocol AttachmentStore: Sendable {
    /// Writes bytes into the store and returns where they landed.
    func store(_ source: AttachmentDraft.Source, kind: AttachmentKind) async throws -> StoredFile

    /// Absolute URL for a stored file — what `AVPlayer` and friends want.
    nonisolated func url(forRelativePath path: String) -> URL

    func remove(relativePath: String) async throws
    func totalByteCount() async throws -> Int
}

nonisolated struct StoredFile: Sendable, Hashable {
    let relativePath: String
    let byteCount: Int
}

nonisolated enum AttachmentStoreError: LocalizedError {
    case unreadableSource(URL)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableSource(let url): return "Could not read \(url.lastPathComponent)."
        case .writeFailed(let reason):   return "Could not save the attachment: \(reason)"
        }
    }
}
