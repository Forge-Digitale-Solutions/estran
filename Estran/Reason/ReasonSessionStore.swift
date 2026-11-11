import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    /// Shared on-device session so `prewarm()` and `generate` hit the same instance.
    enum ReasonSessionStore {
        private static let box = SessionBox()

        static func session() -> LanguageModelSession {
            box.session()
        }

        static func prewarmIfPossible() {
            guard SystemLanguageModel.default.availability == .available else { return }
            session().prewarm()
        }
    }

    /// Lock-guarded session holder; avoids a mutable global that Swift 6 rejects.
    private final class SessionBox: @unchecked Sendable {
        private let lock = NSLock()
        private var cached: LanguageModelSession?

        func session() -> LanguageModelSession {
            lock.lock()
            defer { lock.unlock() }
            if let cached {
                return cached
            }
            let created = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: FoundationModelReasonProvider.instructions)
            cached = created
            return created
        }
    }
#endif

/// One-shot flag shared by the two racing tasks of a timeout.
final class ReasonResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// `true` for the first caller only, so the continuation resumes once.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
