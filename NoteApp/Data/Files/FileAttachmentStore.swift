import Foundation

/// Media on disk, under Application Support, one subfolder per kind.
///
/// Paths stored in the database are *relative*. The app container's absolute
/// path changes between installs and OS updates, so absolute URLs in a database
/// are broken links waiting to happen.
actor FileAttachmentStore: AttachmentStore {
    /// `nonisolated` so `url(forRelativePath:)` can answer during a view body —
    /// `AVPlayer` and `AsyncImage` want a URL, not an await. Safe: it never changes.
    private nonisolated let root: URL
    private let fileManager = FileManager.default

    init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            self.root = support.appending(path: "Media", directoryHint: .isDirectory)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func store(_ source: AttachmentDraft.Source, kind: AttachmentKind) async throws -> StoredFile {
        let folder = root.appending(path: kind.folderName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        switch source {
        case .data(let data, let fileExtension):
            let name = "\(UUID().uuidString).\(Self.normalized(fileExtension))"
            let destination = folder.appending(path: name)
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                throw AttachmentStoreError.writeFailed(error.localizedDescription)
            }
            return StoredFile(relativePath: "\(kind.folderName)/\(name)", byteCount: data.count)

        case .fileURL(let sourceURL):
            // Anything out of PhotosPicker or the Files app arrives security
            // scoped; without this the copy fails on device but works in the
            // simulator, which is a fun bug to chase.
            let scoped = sourceURL.startAccessingSecurityScopedResource()
            defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

            let name = "\(UUID().uuidString).\(Self.normalized(sourceURL.pathExtension))"
            let destination = folder.appending(path: name)

            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
            } catch {
                throw AttachmentStoreError.unreadableSource(sourceURL)
            }

            let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return StoredFile(relativePath: "\(kind.folderName)/\(name)", byteCount: size)
        }
    }

    nonisolated func url(forRelativePath path: String) -> URL {
        root.appending(path: path)
    }

    func remove(relativePath: String) async throws {
        let target = root.appending(path: relativePath)
        guard fileManager.fileExists(atPath: target.path(percentEncoded: false)) else { return }
        try fileManager.removeItem(at: target)
    }

    func totalByteCount() async throws -> Int {
        Self.byteCount(under: root)
    }

    /// Synchronous on purpose: `FileManager.enumerator` vends a classic iterator,
    /// which Swift 6 refuses to advance from an async context.
    private nonisolated static func byteCount(under root: URL) -> Int {
        guard let walker = FileManager.default.enumerator(at: root,
                                                          includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }

        var total = 0
        for case let url as URL in walker {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    private nonisolated static func normalized(_ ext: String) -> String {
        let cleaned = ext.trimmingCharacters(in: .whitespaces).lowercased()
        return cleaned.isEmpty ? "dat" : cleaned
    }
}
