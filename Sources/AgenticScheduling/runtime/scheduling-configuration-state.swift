import Agentic
import Foundation

public extension Scheduling {
    /// What the application found when it looked for scheduling
    /// configuration. Inserted into `ToolServices` instead of a runtime when
    /// there is none to give, so tools can say why.
    enum ConfigurationState: Sendable {
        case loaded(Runtime)
        /// No configuration file at the expected path.
        case missing(expected: String)
        /// The file exists but does not read; the message locates the problem.
        case invalid(file: String, message: String)
    }

    enum ConfigurationFailure: Error, Sendable, LocalizedError {
        case missing(expected: String)
        case invalid(file: String, message: String)
        case notProvided

        public var errorDescription: String? {
            switch self {
            case .missing(let expected):
                return "Scheduling is not configured: no \(SchedulingFrame.fileName) at \(expected)."
            case .invalid(let file, let message):
                return "Scheduling configuration \(file) is invalid: \(message)"
            case .notProvided:
                return "This application does not provide scheduling for its sessions."
            }
        }
    }

    /// The session's runtime, from a directly inserted `Runtime`, the
    /// store's current file, or a loaded `ConfigurationState`; otherwise a
    /// failure saying why not.
    static func runtime(in context: ToolContext) throws -> Runtime {
        if let runtime = try? context.require(Runtime.self) {
            return runtime
        }
        let state: ConfigurationState
        if let store = try? context.require(ConfigurationStore.self) {
            state = store.state()
        } else if let inserted = try? context.require(ConfigurationState.self) {
            state = inserted
        } else {
            throw ConfigurationFailure.notProvided
        }
        switch state {
        case .loaded(let runtime):
            return runtime
        case .missing(let expected):
            throw ConfigurationFailure.missing(expected: expected)
        case .invalid(let file, let message):
            throw ConfigurationFailure.invalid(file: file, message: message)
        }
    }
}
