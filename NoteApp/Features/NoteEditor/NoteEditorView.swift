import SwiftUI

struct NoteEditorView: View {
    let mode: NoteEditorModel.Mode

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: NoteEditorModel?

    var body: some View {
        Group {
            if let model {
                form(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model?.navigationTitle ?? "Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        if await model?.save() == true { dismiss() }
                    }
                }
                .disabled(model?.canSave != true || model?.isBusy == true)
            }
        }
        .task {
            guard model == nil else { return }
            let model = NoteEditorModel(repository: container.notes, mode: mode)
            self.model = model
            await model.load()
        }
    }

    @ViewBuilder
    private func form(_ model: NoteEditorModel) -> some View {
        @Bindable var model = model

        Form {
            Section {
                TextField("Title", text: $model.title)
                    .font(.headline)

                TextField("Write something…", text: $model.content, axis: .vertical)
                    .lineLimit(6...)
            }

            AttachmentSection(model: model)
        }
        .disabled(model.isBusy)
        .alert("Something went wrong",
               isPresented: .init(get: { model.errorMessage != nil },
                                  set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        NoteEditorView(mode: .create)
    }
    .environment(try! AppContainer.ephemeral())
}
