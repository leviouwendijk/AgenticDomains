import Agentic
import AgenticLoa
import Foundation
import Loa
import Primitives
import Surface
import Testing

private enum AgenticLoaTestingFailure: Error {
    case failed
}

@main
struct AgenticLoaTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(AgenticLoaTestSuite.suite, sink: reporter)
        if result.isFailure {
            throw AgenticLoaTestingFailure.failed
        }
    }
}

/// Stands in for the governed program tool executor: records each tool call and answers
/// from a table, or fails or throws as the real one does.
actor FakeProgramTools: ProgramToolExecuting {
    enum Answer: Sendable {
        case output(JSONValue)
        case toolError(String)
        case hostError
    }

    struct Held: Error {}

    var answers: [String: Answer]
    private(set) var calls: [(tool: String, input: JSONValue)] = []

    init(_ answers: [String: Answer]) {
        self.answers = answers
    }

    nonisolated func execute<Input, Output>(
        _ identifier: ToolIdentifier,
        input: Input,
        as output: Output.Type
    ) async throws -> Output where Input: Encodable & Sendable, Output: Decodable & Sendable {
        let json = input as? JSONValue ?? .null
        let answer = await record(identifier.rawValue, json)
        switch answer {
        case .output(let value)?:
            guard let typed = value as? Output else { throw Held() }
            return typed
        case .toolError(let message)?:
            throw ProgramToolFailure(
                tool: identifier,
                result: .init(call: .init(id: "1", name: identifier.rawValue), output: .object(["message": .string(message)]), isError: true)
            )
        case .hostError?, nil:
            throw Held()
        }
    }

    private func record(_ tool: String, _ input: JSONValue) -> Answer? {
        calls.append((tool, input))
        return answers[tool]
    }

    func answer(_ tool: String, with answer: Answer) {
        answers[tool] = answer
    }

    var tools: [String] { calls.map(\.tool) }
}

/// Picks the given option ids.
struct FakeUserInput: UserInputProviding {
    let selected: [String]

    func ask(_ request: UserInputRequest) async throws -> UserInputResponse {
        try UserInputResponse(answer: .choice(.init(selected: selected)), for: request)
    }
}

enum Descriptors {
    static let tools: [ToolDescriptor] = [
        .init(
            identifier: .init(rawValue: "mail_tool_search"),
            description: "Search messages across accounts. Returns summaries.",
            input: .object([
                "type": "object",
                "properties": .object([
                    "text": .object(["type": "string"]),
                    "limit": .object(["type": "integer"]),
                    "level": .object(["type": "string", "enum": .array(["read", "draft"])]),
                    "targets": .object(["type": "array", "items": .object(["type": "string"])]),
                ]),
                "required": .array(["targets"]),
            ]),
            risk: .observe
        ),
        .init(
            identifier: .init(rawValue: "mail_tool_send"),
            description: "Send a message.",
            input: .object([
                "type": "object",
                "properties": .object([
                    "to": .object(["type": "array", "items": .object(["type": "string"])]),
                    "body": .object(["type": "string"]),
                ]),
                "required": .array(["to", "body"]),
            ]),
            risk: .privileged
        ),
        // Not `<domain>_tool_<name>`: left out of the catalog.
        .init(identifier: .init(rawValue: "legacytool"), description: "Old.", risk: .observe),
    ]

    static let domains: [DomainDefinition] = [
        .init(namespace: .init(rawValue: "mail"), name: try? DomainName("mail"), aliases: [try! DomainName("email")]),
    ]

    static let catalog = Loa.Catalog(tools: tools, domains: domains)
}

func runProgram(
    _ source: String,
    tools: FakeProgramTools,
    input: (any UserInputProviding)? = nil,
    ledgers: LoaLedgers = .init(),
    goal: String? = nil
) async throws -> LoaLang.Programs.Run.Output {
    try await LoaLang.Programs.Run(catalog: Descriptors.catalog, ledgers: ledgers).run(
        .init(source: source, goal: goal),
        in: ProgramContext(tools: tools, userInput: input)
    )
}

let searchOutput: JSONValue = .object([
    "messages": .array([.object(["subject": "Pakwerk", "unread": true])]),
])

enum AgenticLoaTestSuite {
    static let suite = TestSuite("agentic_loa", title: "Loa in Agentic") {
        Test("the catalog comes from the tool descriptors") {
            let reference = Descriptors.catalog.reference()
            try Expect.equal(reference, """
                mail (also: email)
                  mail.search(targets: [string], level: .read | .draft?, limit: int?, text: string?) -> any · read — Search messages across accounts.
                  mail.send(to: [string], body: string) -> any · external — Send a message.
                """, "reference")
        }

        Test("values cross as JSON: sorted object keys, cases as their name") {
            let value = Loa.Value(json: .object(["b": 1, "a": .array(["x"])]))
            try Expect.equal(value.description, #".{ .a = ["x"], .b = 1 }"#, "from JSON")
            try Expect.equal(JSONValue(loa: .case(.init("draft"))), .string("draft"), "a case")
            try Expect.equal(
                JSONValue(loa: .record(.init(nil, [.init("to", ["Client A"])]))),
                .object(["to": .array(["Client A"])]),
                "a record"
            )
        }

        Test("a run calls the installed tools by identifier and returns values and calls") {
            let tools = FakeProgramTools([
                "mail_tool_search": .output(searchOutput),
                "mail_tool_send": .output(.object(["id": "m1"])),
            ])
            let output = try await runProgram("""
                page reply {
                    let hits = mail.search(
                        targets: ["levi:*"],
                        text: "pakwerk",
                        level: .read
                    ).messages;

                    let sent = mail.send(
                        to: ["Client A"],
                        body: "Re: \\(hits.only().subject)"
                    );
                }
                """, tools: tools)
            try Expect.equal(output.status, "completed", "status: \(output.message ?? "")")
            let calls = await tools.calls
            try Expect.equal(calls.map(\.tool), ["mail_tool_search", "mail_tool_send"], "tool identifiers")
            try Expect.equal(
                calls[0].input,
                .object(["targets": .array(["levi:*"]), "text": "pakwerk", "level": "read"]),
                "labeled arguments as the tool's JSON input"
            )
            try Expect.equal(calls[1].input, .object(["to": .array(["Client A"]), "body": "Re: Pakwerk"]), "interpolated")
            try Expect.equal(output.calls, ["mail.search ran", "mail.send ran"], "calls")
            guard case .object(let pages) = output.values, case .object(let reply)? = pages["reply"] else {
                throw AgenticLoaTestingFailure.failed
            }
            try Expect.equal(reply["sent"], .object(["id": "m1"]), "values by page")
        }

        Test("a tool's error is a failure value; checker errors stop before anything runs") {
            let tools = FakeProgramTools(["mail_tool_search": .toolError("offline")])
            let handled = try await runProgram("""
                let r = mail.search(
                    targets: ["*"]
                );
                let failed = r.failed;
                let why = r.error.message;
                """, tools: tools)
            try Expect.equal(handled.status, "completed", "handled in the program")
            guard case .object(let pages) = handled.values, case .object(let top)? = pages["_"] else {
                throw AgenticLoaTestingFailure.failed
            }
            try Expect.equal(top["why"], "offline", "the tool's message")

            let invalid = try await runProgram("mail.serch(targets: []);", tools: tools)
            try Expect.equal(invalid.status, "invalid", "invalid")
            try Expect.equal(invalid.diagnostics, ["1:1: error: mail has no function 'serch'. Did you mean 'search'?"], "diagnostics")
        }

        Test("a host error propagates; a later run of the goal reuses the read and sends once") {
            let tools = FakeProgramTools([
                "mail_tool_search": .output(searchOutput),
                "mail_tool_send": .hostError,
            ])
            let ledgers = LoaLedgers()
            let source = """
                let hits = mail.search(
                    targets: ["*"]
                ).messages;
                let sent = mail.send(
                    to: ["Client A"],
                    body: "about \\(hits.count) messages"
                );
                """
            var threw = false
            do {
                _ = try await runProgram(source, tools: tools, ledgers: ledgers, goal: "pakwerk")
            } catch is FakeProgramTools.Held {
                threw = true
            }
            try Expect.equal(threw, true, "the runtime gets the host's error (an approval it holds)")

            await tools.answer("mail_tool_send", with: .output(.object(["id": "m1"])))
            let second = try await runProgram(source, tools: tools, ledgers: ledgers, goal: "pakwerk")
            try Expect.equal(second.status, "completed", "completed")
            let names = await tools.tools
            try Expect.equal(names, ["mail_tool_search", "mail_tool_send", "mail_tool_send"], "search once; the held send once more")
            try Expect.equal(second.calls, ["mail.search reused", "mail.send ran"], "this run's calls")
        }

        Test("ask goes to the Program's user input") {
            let output = try await runProgram("""
                let pick = ask(
                    "Which account?",
                    options: ["levi", "team"]
                );
                """, tools: FakeProgramTools([:]), input: FakeUserInput(selected: ["1"]))
            try Expect.equal(output.status, "completed", "answered by the host")
            guard case .object(let pages) = output.values, case .object(let top)? = pages["_"] else {
                throw AgenticLoaTestingFailure.failed
            }
            try Expect.equal(top["pick"], "team", "the chosen option")

            let waiting = try await runProgram("let pick = ask(\"Which account?\");", tools: FakeProgramTools([:]))
            try Expect.equal(waiting.status, "suspended", "no user input: the run waits")
        }

        Test("check and reference programs") {
            let check = try await LoaLang.Programs.Check(catalog: Descriptors.catalog).run(
                .init(source: "for x in [1, 2] {\n    mail.send(\n        to: [\"a\"],\n        body: \"same\"\n    );\n}"),
                in: ProgramContext()
            )
            try Expect.equal(check.valid, true, "valid")
            try Expect.equal(check.effects, ["mail.send external (loop)"], "effects")
            try Expect.equal(check.diagnostics.count, 1, "the loop warning")

            let reference = try await LoaLang.Programs.Reference(catalog: Descriptors.catalog).run(
                .init(domains: ["email"]),
                in: ProgramContext()
            )
            try Expect.equal(reference.reference.hasPrefix("mail (also: email)"), true, "by alias")
        }
    }
}

// Literals for test JSON only.
extension JSONValue: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: @retroactive ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension JSONValue: @retroactive ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: @retroactive ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}
