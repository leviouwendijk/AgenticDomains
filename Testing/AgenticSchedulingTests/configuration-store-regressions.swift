import Agentic
import AgenticScheduling
import Foundation
import Testing

/// A source that only lists calendars.
private struct CalendarListSource: CalendarSource {
    let identifier = "listed"
    let titles: [String]

    func authorization() async -> CalendarSourceAuthorization { .authorized }

    func calendars() async throws -> [CalendarReference] {
        titles.map { .init(identifier: $0.lowercased().replacingOccurrences(of: " ", with: "-"), title: $0) }
    }

    func events(in interval: ScheduleInterval) async throws -> [ScheduledEvent] { [] }
}

/// The configuration store: calendars listed before any file exists, the
/// check, and a save that archives, refuses invalid text and applies at once.
enum SchedulingConfigurationStoreTests {
    static let exampleTitles = ["Appointments Alex", "Appointments Sam", "Joint", "Open slots Alex", "Internal", "Cancelled"]

    static func fixture() throws -> (ToolContext, Scheduling.ConfigurationStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("scheduling-store-\(UUID().uuidString)", isDirectory: true)
        let file = root.appendingPathComponent("domains/\(SchedulingFrame.fileName)")
        let source = CalendarListSource(titles: exampleTitles)
        let store = Scheduling.ConfigurationStore(
            file: file,
            archiveDirectory: root.appendingPathComponent("archive"),
            sources: [source]
        ) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else {
                return .missing(expected: file.path)
            }
            do {
                let configuration = try SchedulingConfiguration(source: text, filePath: file.path)
                return .loaded(configuration.runtime(sources: [source]))
            } catch {
                return .invalid(file: file.path, message: error.localizedDescription)
            }
        }
        return (ToolContext(services: try ToolServices().inserting(store)), store, root)
    }

    static func calendarsWithoutConfiguration() async throws {
        let (context, _, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let output = try await Scheduling.Tools.ListCalendars().call(.init(), in: context)
        try Expect.equal(output.sources.flatMap(\.calendars).map(\.title), exampleTitles, "real titles before any file exists")
        try Expect.true(output.sources.flatMap(\.calendars).allSatisfy { $0.role == nil }, "no roles without a configuration")
        try Expect.true(output.information_gaps.contains { $0.contains("not configured") }, "says why: \(output.information_gaps)")
    }

    static func check() async throws {
        let (context, _, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let check = Scheduling.Tools.CheckConfiguration()

        let example = try await check.call(.init(text: SchedulingFrame.example), in: context)
        try Expect.equal(example.problems, [], "the example holds")
        try Expect.equal(example.unknown_calendars, [], "its calendars exist")
        try Expect.true(example.valid, "valid")
        try Expect.equal(example.participants, ["alex", "sam"], "participants in order")

        let misspelt = SchedulingFrame.example.replacingOccurrences(of: "\"Joint\"", with: "\"Jiont\"")
        let unknown = try await check.call(.init(text: misspelt), in: context)
        try Expect.false(unknown.valid, "an unknown calendar is not valid")
        try Expect.equal(unknown.unknown_calendars, ["Jiont"], "names it")

        let typo = SchedulingFrame.example.replacingOccurrences(of: ".overrunMinutes = 15,", with: ".overunMinutes = 15,")
        let schema = try await check.call(.init(text: typo), in: context)
        try Expect.true(schema.problems.contains { $0.contains("overunMinutes") && $0.first?.isNumber == true }, "a typo with its line: \(schema.problems)")

        let conflicting = """
            import Scheduling;
            let a: Calendar = .{ .title = "Joint", .role = .offers };
            let b: Calendar = .{ .title = "Joint", .role = .records };
            """
        let meaning = try await check.call(.init(text: conflicting), in: context)
        try Expect.true(meaning.problems.contains { $0.contains("declared twice") }, "what only scheduling rejects: \(meaning.problems)")
    }

    static func save() async throws {
        let (context, store, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let save = Scheduling.Tools.SaveConfiguration()

        let refused = try await save.call(.init(text: "import Scheduling;\nlet x: Calendar = .{ };\n"), in: context)
        try Expect.false(refused.saved, "an invalid file is refused")
        try Expect.equal(try store.text(), nil, "and nothing is written")

        let first = try await save.call(.init(text: SchedulingFrame.example), in: context)
        try Expect.true(first.saved, "saved: \(first.problems)")
        try Expect.equal(first.archived, nil, "nothing to archive")
        let context_ = try await Scheduling.Tools.Context().call(.init(), in: context)
        try Expect.equal(context_.participants.map(\.identifier), ["alex", "sam"], "scheduling uses it at once")

        let refined = SchedulingFrame.example.replacingOccurrences(of: ".bufferMinutes = 15,", with: ".bufferMinutes = 10,")
        let second = try await save.call(.init(text: refined), in: context)
        try Expect.true(second.saved, "a refinement saves")
        let archived = try String(contentsOf: URL(fileURLWithPath: second.archived ?? "/missing"), encoding: .utf8)
        try Expect.equal(archived, SchedulingFrame.example, "the previous file is archived whole")

        let misspelt = SchedulingFrame.example.replacingOccurrences(of: "\"Joint\"", with: "\"Elsewhere\"")
        let unknown = try await save.call(.init(text: misspelt), in: context)
        try Expect.false(unknown.saved, "unknown calendars are refused")
        let accepted = try await save.call(.init(text: misspelt, accept_unknown_calendars: true), in: context)
        try Expect.true(accepted.saved, "unless accepted")

        // Archives are the only copies: Writers makes no backups of its own.
        let made = try FileManager.default.subpathsOfDirectory(atPath: root.path)
        try Expect.true(!made.contains { $0.contains("safe-file-backups") || $0.contains(".bak") }, "no Writers backups: \(made)")
    }
}
