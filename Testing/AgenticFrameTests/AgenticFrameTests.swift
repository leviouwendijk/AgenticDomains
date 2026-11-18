import Agentic
import AgenticFrame
import Foundation
import Frame
import Testing

private enum AgenticFrameTestingFailure: Error {
    case failed
}

@main
struct AgenticFrameTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(
            AgenticFrameTestSuite.suite,
            sink: reporter
        )
        if result.isFailure {
            throw AgenticFrameTestingFailure.failed
        }
    }
}

enum AgenticFrameTestSuite {
    static let suite = TestSuite(
        "agentic-frame",
        title: "AgenticFrame"
    ) {
        Test("modules-compiled-win-over-files") {
            try await FrameLangTests.modules()
        }
        Test("schema-renders-module-source") {
            try await FrameLangTests.schema()
        }
        Test("check-reports-every-problem-by-line") {
            try await FrameLangTests.check()
        }
    }
}

/// A compiled module, `Pets`, and a folder holding a stale `Pets.frame` and
/// a file-only `Garden.frame`.
enum FrameLangTests {
    struct Pet: Decodable, Sendable, FrameDescribable {
        enum Kind: String, Decodable, Sendable, CaseIterable { case dog, cat }
        let name: String
        let kind: Kind?

        static var frameSchema: Frame.Schema {
            .object([
                .init("name", .string, required: true, summary: "What it answers to."),
                .init("kind", .members(of: Kind.self)),
            ], summary: "A pet.")
        }
    }

    static let pets = Frame.Module("Pets", types: [.decodable(Pet.self, named: "Pet")])

    static func fixture() throws -> (ToolContext, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frame-modules-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "import Frame;\nlet Pet: Type = .{ .properties = [] };\n"
            .write(to: directory.appendingPathComponent("Pets.frame"), atomically: true, encoding: .utf8)
        try "import Frame;\nlet Bed: Type = .{ .properties = [.{ .name = \"plant\", .type = .string, .required = true }] };\n"
            .write(to: directory.appendingPathComponent("Garden.frame"), atomically: true, encoding: .utf8)
        let context = ToolContext(services: try ToolServices().inserting(
            FrameLang.Modules(compiled: [pets], directory: directory)
        ))
        return (context, directory)
    }

    static func modules() async throws {
        let (context, directory) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = try await FrameLang.Tools.ListModules().call(.init(), in: context)
        try Expect.equal(output.modules.map(\.name), ["Pets", "Garden"], "compiled first, then files the program lacks")
        try Expect.equal(output.modules.map(\.origin), [.program, .file], "by origin")
        try Expect.equal(output.modules[0].stale_file, true, "the Pets file differs from the program")
        try Expect.equal(output.modules[1].types, ["Bed"], "file types")

        try pets.install(into: directory)
        let fresh = try await FrameLang.Tools.ListModules().call(.init(), in: context)
        try Expect.equal(fresh.modules[0].stale_file, false, "an installed module is not stale")
    }

    static func schema() async throws {
        let (context, directory) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = try await FrameLang.Tools.ModuleSchema().call(.init(module: "Pets"), in: context)
        try Expect.equal(output.origin, .program, "the compiled module, not the stale file")
        try Expect.true(output.source.contains("What it answers to."), "summaries are in the source")
        try Expect.true(output.source.contains("dog"), "members are in the source")
        do {
            _ = try await FrameLang.Tools.ModuleSchema().call(.init(module: "Nope"), in: context)
            try Expect.true(false, "an unknown module must fail")
        } catch let failure as FrameLang.ToolFailure {
            try Expect.true(failure.localizedDescription.contains("Pets, Garden"), "names what there is")
        }
    }

    static func check() async throws {
        let (context, directory) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let check = FrameLang.Tools.Check()

        let valid = try await check.call(.init(text: """
            import Pets;
            import Garden;
            let rex: Pet = .{ .name = "Rex", .kind = .dog };
            let roses: Bed = .{ .plant = "roses" };
            """), in: context)
        try Expect.equal(valid.problems, [], "valid against compiled and file modules")
        try Expect.true(valid.valid, "valid")
        try Expect.equal(valid.imports, ["Pets (program)", "Garden (file)"], "imports by origin")

        let wrong = try await check.call(.init(text: """
            import Pets;
            let rex: Pet = .{
                .nmae = "Rex",
                .kind = .parrot,
            };
            """), in: context)
        try Expect.false(wrong.valid, "invalid")
        try Expect.true(wrong.problems.contains { $0.hasPrefix("3:") && $0.contains("nmae") }, "a typo on its line: \(wrong.problems)")
        try Expect.true(wrong.problems.contains { $0.hasPrefix("4:") && $0.contains("parrot") }, "an unknown member on its line: \(wrong.problems)")
        try Expect.true(wrong.problems.contains { $0.contains("name") && !$0.contains("nmae") }, "a missing required field: \(wrong.problems)")

        let syntax = try await check.call(.init(text: "let rex = .{ .name = ", file: "pets.frame"), in: context)
        try Expect.false(syntax.valid, "a syntax error is a problem too")
        try Expect.equal(syntax.problems.count, 1, "reported once")

        let unknown = try await check.call(.init(text: "import Nope;\n"), in: context)
        try Expect.false(unknown.valid, "an unknown import is a problem")
        try Expect.equal(unknown.imports, ["Nope (unknown)"], "and marked unknown")
    }
}
