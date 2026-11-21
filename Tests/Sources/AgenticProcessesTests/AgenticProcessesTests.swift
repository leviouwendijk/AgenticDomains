import Agentic
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
