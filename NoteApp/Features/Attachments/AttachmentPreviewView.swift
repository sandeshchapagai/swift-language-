import AVKit
import SwiftUI

/// Plays or shows one attachment. Takes a plain file URL, so it needs to know
/// nothing about how or where attachments are stored.
struct AttachmentPreviewView: View {
    let attachment: Attachment
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(attachment.kind.rawValue.capitalized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch attachment.kind {
        case .image:
            if let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                missingFile
            }

        case .video, .audio:
            VideoPlayer(player: AVPlayer(url: url))

        case .file:
            ShareLink(item: url) {
                Label("Open \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var missingFile: some View {
        ContentUnavailableView("File Missing",
                               systemImage: "questionmark.folder",
                               description: Text("The attachment couldn't be found on disk."))
    }
}
