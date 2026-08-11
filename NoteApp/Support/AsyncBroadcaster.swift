import Foundation

/// Fan-out of a value to any number of `for await` loops.
///
/// `AsyncStream` is single-consumer, but the list screen and the editor both
/// want the same notifications, so this hands each caller its own stream.
/// `nonisolated` because the target defaults new code to `@MainActor`. Nothing
/// below the feature layer belongs on the main actor, and this in particular is
/// read by actors and background tasks.
nonisolated final class AsyncBroadcaster<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]

    init() {}

    func stream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { _ = self.continuations.removeValue(forKey: id) }
            }
        }
    }

    func send(_ value: Element) {
        let current = lock.withLock { continuations }
        for continuation in current.values {
            continuation.yield(value)
        }
    }
}

nonisolated extension AsyncBroadcaster where Element == Void {
    func send() { send(()) }
}
