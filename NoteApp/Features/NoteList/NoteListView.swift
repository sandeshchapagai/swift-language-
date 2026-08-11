import SwiftUI

struct NoteListView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: NoteListModel?
    @State private var editing: NoteEditorModel.Mode?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    listContent(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Note", systemImage: "square.and.pencil") {
                        editing = .create
                    }
                }
            }
            .sheet(item: $editing) { mode in
                NavigationStack {
                    NoteEditorView(mode: mode)
                }
            }
        }
        .task {
            guard model == nil else { return }
            let model = NoteListModel(repository: container.notes)
            self.model = model
            await model.load()
        }
        .task {
            guard let model else { return }
            await model.observeChanges()
        }
    }

    @ViewBuilder
    private func listContent(_ model: NoteListModel) -> some View {
        @Bindable var model = model

        List {
            ForEach(model.summaries) { summary in
                Button {
                    editing = .edit(summary.id)
                } label: {
                    NoteRow(summary: summary)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                Task { await model.delete(at: offsets) }
            }
        }
        .listStyle(.plain)
        .searchable(text: $model.searchText, prompt: "Search notes")
        .overlay {
            if model.summaries.isEmpty && !model.isLoading {
                emptyState(searching: !model.searchText.isEmpty)
            }
        }
        .alert("Something went wrong",
               isPresented: .init(get: { model.errorMessage != nil },
                                  set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func emptyState(searching: Bool) -> some View {
        if searching {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView {
                Label("No Notes Yet", systemImage: "note.text")
            } description: {
                Text("Tap the pencil to write your first one.")
            }
        }
    }
}

private struct NoteRow: View {
    let summary: NoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.displayTitle)
                .font(.headline)
                .lineLimit(1)

            if !summary.snippet.isEmpty {
                Text(summary.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Text(summary.updatedAt, format: .relative(presentation: .named))

                ForEach(Array(summary.attachmentKinds).sorted(by: { $0.rawValue < $1.rawValue }),
                        id: \.self) { kind in
                    Image(systemName: kind.systemImage)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

extension NoteEditorModel.Mode: Identifiable {
    var id: String {
        switch self {
        case .create:        return "create"
        case .edit(let id):  return id.uuidString
        }
    }
}

#Preview {
    NoteListView()
        .environment(try! AppContainer.ephemeral())
}
