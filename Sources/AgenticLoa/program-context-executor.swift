import Agentic
import Loa
import Primitives
import Surface

/// Runs a Loa program's calls through a Program context: each call is the installed tool
/// `<domain>_tool_<name>`, invoked the way any Program invokes tools, so preflight,
/// approval and recovery stay the dispatcher's. Loa never calls a tool directly.
struct ProgramContextExecutor: Loa.Executor {
    let context: ProgramContext

    func call(_ call: Loa.Call) async throws -> Loa.CallOutcome {
        var input: [String: JSONValue] = [:]
        for argument in call.arguments {
            guard let label = argument.label else {
                return .not_run("\(call.qualifiedName) takes labeled arguments")
            }
            input[label] = JSONValue(loa: argument.value)
        }
        let identifier = ToolIdentifier(rawValue: "\(call.domain)_tool_\(call.function)")
        do {
            let output = try await context.invoke(identifier, input: JSONValue.object(input), as: JSONValue.self)
            return .value(Loa.Value(json: output))
        } catch let failure as ProgramToolFailure {
            // The tool ran and reported an error: a failure value the program can handle.
            return .failure(failure.result.text ?? Self.message(failure.result.output))
        } catch ProgramContextError.toolInvocationUnavailable {
            return .not_run("this host does not run tools for programs")
        }
        // Anything else is the host's: an approval it holds, a denial, cancellation. It
        // propagates, the call is recorded as pending, and the runtime handles it.
    }

    /// Asks the owner through the Program's user input, when the host has one.
    func ask(_ question: Loa.Question, call: Loa.Call) async throws -> Loa.Value? {
        let options = question.options ?? []
        let input: SurfaceQuestion
        if question.options != nil {
            input = .choice(
                SurfaceChoice(
                    options: options.enumerated().map { index, option in
                        SurfaceChoice.Option(id: String(index), label: option.text, value: option.text)
                    },
                    rule: question.multiple ? .many : .one
                )
            )
        } else {
            input = .text(.init())
        }
        let response: UserInputResponse
        do {
            response = try await context.ask(try UserInputRequest(prompt: question.prompt, input: input))
        } catch ProgramContextError.userInputUnavailable {
            return nil
        }
        // Skipped: leave it open for the owner.
        guard let answer = response.answer else { return nil }
        switch answer {
        case .text(let text):
            return .string(text)
        case .choice(let choice):
            let picked = choice.selected.compactMap(Int.init).filter(options.indices.contains).map { options[$0] }
            if question.multiple { return .array(picked) }
            if let first = picked.first { return first }
            return choice.custom.map(Loa.Value.string)
        case .confirmation(let flag):
            return .bool(flag)
        case .form:
            return nil
        }
    }

    /// A failed tool's output as one line.
    static func message(_ output: JSONValue) -> String {
        if case .object(let fields) = output {
            for key in ["message", "error", "reason"] {
                if case .string(let text)? = fields[key] { return text }
            }
        }
        if case .string(let text) = output { return text }
        return "the tool reported an error"
    }
}

/// Ledgers by goal, kept for the life of the process: later runs of the same goal reuse
/// what earlier runs did and never repeat a guarded call. Storage on disk comes with goals
/// (P3).
public actor LoaLedgers {
    private var ledgers: [String: Loa.Ledger] = [:]

    public init() {}

    public func ledger(for goal: String) -> Loa.Ledger {
        ledgers[goal] ?? .init()
    }

    public func store(_ ledger: Loa.Ledger, for goal: String) {
        ledgers[goal] = ledger
    }
}
