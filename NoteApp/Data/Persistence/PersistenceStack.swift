import Foundation
import SwiftData

/// Builds the SwiftData container. Kept apart from the app entry point so tests
/// and previews can spin up a throwaway store with the same schema.
nonisolated enum PersistenceStack {
    static let schema = Schema([NoteEntity.self, AttachmentEntity.self])

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
