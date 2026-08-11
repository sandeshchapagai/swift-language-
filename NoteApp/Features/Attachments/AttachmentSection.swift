import PhotosUI
import SwiftUI

/// Attachment list plus the picker, as a `Form` section.
struct AttachmentSection: View {
    let model: NoteEditorModel

    @Environment(AppContainer.self) private var container
    @State private var pickerItem: PhotosPickerItem?
    @State private var preview: Attachment?

    var body: some View {
        Section("Attachments") {
            ForEach(model.attachments) { attachment in
                Button {
                    preview = attachment
                } label: {
                    AttachmentRow(attachment: attachment,
                                  url: container.attachments.url(forRelativePath: attachment.relativePath))
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task { await model.removeAttachment(attachment) }
                    }
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                Label("Add Photo or Video", systemImage: "paperclip")
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                defer { pickerItem = nil }
                if let draft = try? await AttachmentImporter.draft(from: item) {
                    await model.addAttachment(draft)
                }
            }
        }
        .sheet(item: $preview) { attachment in
            AttachmentPreviewView(
                attachment: attachment,
                url: container.attachments.url(forRelativePath: attachment.relativePath)
            )
        }
    }
}

struct AttachmentRow: View {
    let attachment: Attachment
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.kind.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if attachment.kind == .image, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: attachment.kind.systemImage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        var parts = [attachment.byteCount.formatted(.byteCount(style: .file))]
        if let duration = attachment.duration {
            parts.append(Self.timecode(duration))
        }
        return parts.joined(separator: " · ")
    }

    private static func timecode(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
