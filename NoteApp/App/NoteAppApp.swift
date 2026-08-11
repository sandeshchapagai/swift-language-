import SwiftUI

@main
struct NoteAppApp: App {
    @State private var container: AppContainer?
    @State private var startupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    NoteListView()
                        .environment(container)
                } else if let startupError {
                    StartupFailureView(message: startupError)
                } else {
                    ProgressView()
                }
            }
            .task { start() }
        }
    }

    /// Building the store can fail (disk full, incompatible schema). Crashing on
    /// it hides the cause; showing it means a bug report says what happened.
    private func start() {
        guard container == nil, startupError == nil else { return }
        do {
            container = try AppContainer.live()
        } catch {
            startupError = error.localizedDescription
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't open your notes", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}
