import Agentic
import AgenticIO
import AgenticProcesses
import Foundation
import Testing

private enum AgenticProcessesTestingFailure: Error {
    case failed
}

@main
struct AgenticProcessesTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(
            AgenticProcessesTestSuite.suite,
            sink: reporter
        )
        if result.isFailure {
            throw AgenticProcessesTestingFailure.failed
        }
    }
}

enum AgenticProcessesTestSuite {
    static let suite = TestSuite(
        "agentic-processes",
        title: "AgenticProcesses"
    ) {
        Test("read-shaped-commands-get-a-hint") {
            try NativeReadHintTests.readShaped()
        }
        Test("commands-that-may-write-get-none") {
            try NativeReadHintTests.mayWrite()
        }
        Test("hint-names-the-matching-tools") {
            try NativeReadHintTests.text()
        }
        Test("reads-translate-to-read-files") {
            try NativeReadEquivalentTests.reads()
        }
        Test("searches-translate-to-search-sources") {
            try NativeReadEquivalentTests.searches()
        }
        Test("listings-translate-to-scan-filepaths") {
            try NativeReadEquivalentTests.listings()
        }
        Test("untranslatable-commands-name-the-tool-only") {
            try NativeReadEquivalentTests.untranslatable()
        }
    }
}

/// Every suggested input is decoded through the tool's own input type, so a
/// passing test means the hint is a valid call, not a lookalike string.
enum NativeReadEquivalentTests {
    typealias Hint = Shell.NativeReadHint
    typealias ReadTool = SystemIO.Tools.Read
    typealias SearchTool = SystemIO.Tools.Search
    typealias FindTool = SystemIO.Tools.Find

    static func single<Input: Decodable>(
        _ command: String,
        _ tool: ToolIdentifier,
        as type: Input.Type
    ) throws -> Input {
        let equivalents = Hint.equivalents(of: command)
        try Expect.equal(equivalents.map(\.tool), [tool], command)
        return try JSONDecoder().decode(type, from: Data(equivalents[0].input.utf8))
    }

    static func reads() throws {
        let headed = try single("cat a.swift | head -100", ReadTool.identifier, as: ReadTool.Input.self)
        try Expect.equal(headed.path, "a.swift", "path")
        try Expect.equal(headed.maxLines, 100, "maxLines from head")

        let ranged = try single("nl -ba a.swift | sed -n '145,360p'", ReadTool.identifier, as: ReadTool.Input.self)
        try Expect.equal(ranged.startLine, 145, "startLine from sed")
        try Expect.equal(ranged.endLine, 360, "endLine from sed")
        try Expect.true(ranged.includeLineNumbers, "nl numbers lines")

        let several = try single(
            "cd Sources && cat a.swift; cat b.swift; sed -n '1,90p' c.swift",
            ReadTool.identifier,
            as: ReadTool.Input.self
        )
        try Expect.equal(several.reads.map(\.path), ["Sources/a.swift", "Sources/b.swift", "Sources/c.swift"], "one batched call, joined to cd")
        try Expect.equal(several.reads.map(\.endLine), [nil, nil, 90], "only the sed read is windowed")
    }

    static func searches() throws {
        let alternation = try single("rg -n 'wrap|tabWidth' Sources | head -65", SearchTool.identifier, as: SearchTool.Input.self)
        try Expect.equal(alternation.pattern, "wrap|tabWidth", "rg regex as pattern")
        try Expect.equal(alternation.includes, ["Sources/**"], "directory as include")
        try Expect.true(alternation.caseSensitive, "rg is case-sensitive")

        let basic = try single("grep -rn 'oldLine\\|newLine' Sources/ --include=*.swift", SearchTool.identifier, as: SearchTool.Input.self)
        try Expect.equal(basic.pattern, "oldLine|newLine", "basic alternation translated")
        try Expect.equal(basic.includes, ["Sources/**/*.swift"], "include glob under the path")

        let literal = try single("grep -rni x . 2>/dev/null | grep -v .build | head", SearchTool.identifier, as: SearchTool.Input.self)
        try Expect.equal(literal.query, "x", "plain text as query")
        try Expect.false(literal.caseSensitive, "-i")
    }

    static func listings() throws {
        let found = try single("cd Sources && find . -type f -maxdepth 2 | head", FindTool.identifier, as: FindTool.Input.self)
        try Expect.equal(found.path, "Sources", "cd as path")
        try Expect.false(found.includeDirectories, "-type f")
        try Expect.equal(found.maxdepth, 2, "-maxdepth")
        try Expect.equal(found.maxEntries, 10, "head as maxEntries")

        let listed = try single("ls -la", FindTool.identifier, as: FindTool.Input.self)
        try Expect.true(listed.path == nil, "root")
        try Expect.true(listed.includeHidden, "-a")
    }

    static func untranslatable() throws {
        let commands = [
            "cat a.swift | tail -35",
            "cat Sources/*.swift",
            "cat /etc/hosts",
            "cat ../a.swift",
            "cat a.swift b.swift | head",
            "grep -c x a.swift",
            "find . -name '*.swift'",
            "ls Sources | grep -i agentic",
        ]

        for command in commands {
            try Expect.isEmpty(Hint.equivalents(of: command), command)
            let hint = Hint.hint(for: command)
            try Expect.true(hint != nil, "still hinted: \(command)")
            try Expect.false(hint?.contains("Equivalent") ?? true, "no input: \(command)")
        }
    }
}

enum NativeReadHintTests {
    typealias Hint = Shell.NativeReadHint

    static func readShaped() throws {
        let cases: [(String, Set<Hint.Use>)] = [
            ("cat a.swift | head -100", [.read]),
            ("cat a.swift; cat b.swift; sed -n '1,90p' c.swift", [.read]),
            ("nl -ba a.swift | sed -n '145,360p'", [.read]),
            ("rg -n 'wrap|tabWidth' Sources | head -65", [.search]),
            ("grep -rn x . 2>/dev/null | grep -v .build | head", [.search]),
            ("find Sources -type f | head", [.list]),
            ("cd Sources && ls", [.list]),
            ("echo ===; cat a.swift | tail -35", [.read]),
            ("ls Sources | sort | uniq", [.list]),
            ("ls Sources | grep -i agentic", [.list]),
            ("cat a.swift || grep -rn x Sources", [.read, .search]),
        ]

        for (command, expected) in cases {
            try Expect.equal(Hint.uses(of: command), expected, command)
        }
    }

    static func mayWrite() throws {
        let commands = [
            "sed -i '' 's/a/b/' a.swift",
            "find . -name '*.orig' -delete",
            "find . -name x -exec rm {} +",
            "cat a.swift > b.swift",
            "cat a.swift | tee b.swift",
            "sort -o out.txt in.txt",
            "cat $(ls)",
            "cat \"$(ls)\"",
            "cat `ls`",
            "cat <<EOF",
            "swift build 2>&1 | tail -3",
            "git status --short | head",
            "echo done",
            "cat 'unterminated",
        ]

        for command in commands {
            try Expect.isEmpty(Hint.uses(of: command), command)
            try Expect.true(Hint.hint(for: command) == nil, command)
        }
    }

    static func text() throws {
        let hint = Hint.hint(for: "cat a.swift; rg -n x Sources | head") ?? ""

        for use in [Hint.Use.read, .search] {
            for identifier in use.identifiers {
                try Expect.true(hint.contains("`\(identifier.rawValue)`"), "names \(identifier.rawValue)")
            }
        }
        for identifier in Hint.Use.list.identifiers {
            try Expect.false(hint.contains("`\(identifier.rawValue)`"), "leaves out \(identifier.rawValue)")
        }
    }
}
