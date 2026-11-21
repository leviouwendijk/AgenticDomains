import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("configuration")
    struct ReadConfiguration {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// Where the file lives.
            public let file: String
            /// The current file; absent when there is none yet.
            public let text: String?
            /// Why the current file does not load; absent when it does, or
            /// when there is no file.
            public let problem: String?
            /// A complete example with made-up people and calendars, to
            /// start from when there is no file.
            public let example: String
        }

        public static let purpose =
            "The current \(SchedulingFrame.fileName) (the team's scheduling configuration) with where it lives and why it does not load, if so; plus a complete example. Read it before writing or changing the configuration."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let store = try Scheduling.store(in: context)
            let problem: String?
            switch store.state() {
            case .invalid(_, let message):
                problem = message
            case .loaded, .missing:
                problem = nil
            }
            return .init(
                file: store.file.path,
                text: try store.text(),
                problem: problem,
                example: SchedulingFrame.example
            )
        }
    }

    @Tool("check_configuration")
    struct CheckConfiguration {
        @JSONSchema
        public struct Input: HashableSource {
            /// The whole \(SchedulingFrame.fileName) text.
            public let text: String

            public init(text: String) {
                self.text = text
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// Usable as it is: no problems and no unknown calendars.
            public let valid: Bool
            /// What makes it unusable, with `line:column:` where known.
            public let problems: [String]
            /// Calendars it names that no calendar source shows: a
            /// misspelt title, or a calendar this Mac does not see.
            public let unknown_calendars: [String]
            /// What could not be checked, and other remarks.
            public let notes: [String]
            /// The participants it declares, in order; the first is the
            /// default.
            public let participants: [String]
        }

        public static let purpose =
            "Check a \(SchedulingFrame.fileName) text without saving it: syntax, every field against the Scheduling schema, what scheduling makes of it (such as a calendar declared twice), and whether each calendar it names exists in the calendar sources. Run it until it is valid before schedule_tool_save_configuration."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let check = await SchedulingConfigurationCheck.run(
                input.text,
                sources: Scheduling.sources(in: context) ?? []
            )
            return .init(
                valid: check.isValid && check.unknownCalendars.isEmpty,
                problems: check.problems,
                unknown_calendars: check.unknownCalendars,
                notes: check.notes,
                participants: check.participants
            )
        }
    }

    @Tool("save_configuration")
    struct SaveConfiguration {
        @JSONSchema
        public struct Input: HashableSource {
            /// The whole \(SchedulingFrame.fileName) text.
            public let text: String
            /// Save even though it names calendars no source shows, for a
            /// calendar the user says exists elsewhere. Defaults to false.
            public let accept_unknown_calendars: Bool?

            public init(text: String, accept_unknown_calendars: Bool? = nil) {
                self.text = text
                self.accept_unknown_calendars = accept_unknown_calendars
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let saved: Bool
            public let file: String
            /// The previous file, kept.
            public let archived: String?
            /// Why it was not saved.
            public let problems: [String]
            public let unknown_calendars: [String]
            public let notes: [String]
        }

        public static let purpose =
            "Save the team's \(SchedulingFrame.fileName), replacing the current one (which is archived). Checks it first exactly as schedule_tool_check_configuration does and refuses an invalid file. Scheduling uses the saved file at once. Only after the user has seen what will be saved."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let store = try Scheduling.store(in: context)
            let check = await SchedulingConfigurationCheck.run(
                input.text,
                sources: Scheduling.sources(in: context) ?? store.sources
            )
            let acceptsUnknown = input.accept_unknown_calendars ?? false
            guard check.isValid, check.unknownCalendars.isEmpty || acceptsUnknown else {
                return .init(
                    saved: false,
                    file: store.file.path,
                    archived: nil,
                    problems: check.problems.isEmpty
                        ? ["Calendars no source shows: \(check.unknownCalendars.joined(separator: ", ")). Correct them, or save with accept_unknown_calendars when the user confirms they exist."]
                        : check.problems,
                    unknown_calendars: check.unknownCalendars,
                    notes: check.notes
                )
            }
            let archived = try store.save(input.text)
            var notes = check.notes
            if case .invalid(_, let message) = store.state() {
                notes.append("Saved, but it does not load: \(message)")
            }
            return .init(
                saved: true,
                file: store.file.path,
                archived: archived?.path,
                problems: [],
                unknown_calendars: check.unknownCalendars,
                notes: notes
            )
        }
    }
}
