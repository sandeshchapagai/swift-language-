import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Turns whatever the system pickers hand back into an `AttachmentDraft`.
///
/// This is the seam between UI frameworks and the domain: `PhotosPickerItem` is
/// a SwiftUI type and has no business reaching a repository, so the conversion
/// stops here.
enum AttachmentImporter {
    static func draft(from item: PhotosPickerItem) async throws -> AttachmentDraft? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                return nil
            }
            // Videos come across as a file rather than `Data` on purpose — a few
            // minutes of 4K is hundreds of megabytes and loading that into memory
            // is how a picker turns into a crash report.
            return AttachmentDraft(kind: .video,
                                   source: .fileURL(movie.url),
                                   duration: await duration(of: movie.url))
        }

        guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        return AttachmentDraft(kind: .image, source: .data(data, fileExtension: ext))
    }

    private static func duration(of url: URL) async -> TimeInterval? {
        guard let seconds = try? await AVURLAsset(url: url).load(.duration).seconds,
              seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }
}

/// `PhotosPickerItem` will only vend a movie as a file. This receives it into a
/// temporary URL that the attachment store then copies from.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = URL.temporaryDirectory.appending(path: "picked-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
