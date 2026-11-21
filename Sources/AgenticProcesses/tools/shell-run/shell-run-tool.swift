import Agentic
import AgenticIO
import Foundation
import Processes
import Schema
import Macros
import Workspace

/// Run one shell command line in the current Agentic workspace.
@JSONSchema
public struct ShellRunToolInput:
    Sendable,
    Codable,
    Hashable
{
    public let command: String
    public let timeoutSeconds: Int?

    public init(
        command: String,
        timeoutSeconds: Int? = nil
    ) {
        self.command = command
        self.timeoutSeconds = timeoutSeconds
    }
}

@JSONSchema
public struct ShellRunToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let command: String
    public let workingDirectory: String
    public let exitCode: Int?
    public let signal: Int?
    public let succeeded: Bool
    public let stdout: String
    public let stderr: String
    public let truncated: Bool
    /// The native tools that do what this read-only command did.
    public let hint: String?

    public init(
        command: String,
        workingDirectory: String,
        exitCode: Int?,
        signal: Int?,
        succeeded: Bool,
        stdout: String,
        stderr: String,
        truncated: Bool,
        hint: String? = nil
    ) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = exitCode
        self.signal = signal
        self.succeeded = succeeded
        self.stdout = stdout
        self.stderr = stderr
        self.truncated = truncated
        self.hint = hint
    }
}

public extension Shell.Tools {
    /// Definition risk is the ceiling; preflight may only lower it to boundedmutate
    /// through the trusted host's Shell.CommandPolicy, never to observe.
    @Tool("shell_run")
    struct Run {
        public typealias Input = ShellRunToolInput
        public typealias Output = ShellRunToolOutput

        public static let purpose =
            """
            Run one shell command line in the current Agentic workspace directory and return its exit status, stdout and stderr. For programs; to read, list or search files use \(SystemIO.Tools.ReadFiles.identifier.rawValue), \(SystemIO.Tools.ScanFilepaths.identifier.rawValue) or \(SystemIO.Tools.SearchSources.identifier.rawValue), which usually need no review and take several files in one call. Long output keeps only its tail. Always requires review unless the host allowlists the exact program for a plain, metacharacter-free invocation.
            """

        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(
            _ input: Input,
            in context: ToolContext
        ) async throws -> ToolPreflight {
            let run = try resolvedContext(
                input,
                in: context
            )
            let risk = run.policy.risk(
                for: run.command
            )
            var warnings = risk == .privileged
                ? [
                    "Arbitrary shell execution is not sandboxed by this tool.",
                ]
                : []
            if let hint = Shell.NativeReadHint.hint(for: run.command) {
                warnings.append(hint)
            }

            return .init(
                tool: Self.definition.identifier,
                risk: risk,
                summary: "Run `\(run.command)` in \(run.workingDirectory.path).",
                access: .init(
                    roots: [
                        run.workingDirectory.path,
                    ]
                ),
                estimates: .init(
                    runtime: TimeInterval(run.timeoutSeconds)
                ),
                preview: .init([
                    .command(
                        .init(
                            run.command,
                            workingDirectory: run.workingDirectory.path
                        )
                    ),
                ]),
                mayChangeSource: true,
                sideEffects: [
                    "spawn \(run.policy.shell) -c with the given command line",
                    "may read, write or delete files and reach the network as the host user",
                    "terminate the process group after \(run.timeoutSeconds)s",
                ],
                policyChecks: [
                    "workspace_required",
                    "non_empty_command",
                    "timeout_within_host_maximum",
                    "host_command_policy",
                    risk == .boundedmutate
                        ? "allowlisted_plain_invocation"
                        : "unrestricted_shell_privileged",
                    "isolated_process_group",
                ],
                warnings: warnings
            )
        }

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let run = try resolvedContext(
                input,
                in: context
            )
            let result = try await ProcessRunner().run(
                .init(
                    executable: .path(run.policy.shell),
                    arguments: [
                        "-c",
                        run.command,
                    ],
                    workingDirectory: run.workingDirectory,
                    environment: run.policy.environment,
                    outputLimit: run.policy.outputLimit,
                    timeout: .seconds(run.timeoutSeconds)
                )
            )
            let stdout = tail(
                result.stdoutText,
                limit: run.policy.resultCharacterLimit
            )
            let stderr = tail(
                result.stderrText,
                limit: run.policy.resultCharacterLimit
            )

            return .init(
                command: run.command,
                workingDirectory: run.workingDirectory.path,
                exitCode: result.exitCode.map(Int.init),
                signal: result.signal.map(Int.init),
                succeeded: result.isSuccess,
                stdout: stdout.text,
                stderr: stderr.text,
                truncated: stdout.truncated || stderr.truncated,
                hint: Shell.NativeReadHint.hint(
                    for: run.command
                )
            )
        }
    }
}

private extension Shell.Tools.Run {
    struct RunContext:
        Sendable
    {
        let policy: Shell.CommandPolicy
        let command: String
        let workingDirectory: URL
        let timeoutSeconds: Int
    }

    func resolvedContext(
        _ input: Input,
        in context: ToolContext
    ) throws -> RunContext {
        let toolName = Self.definition.identifier.rawValue

        guard let workspace = context.workspace else {
            throw AgenticProcessesToolError.workspaceRequired(
                toolName
            )
        }

        let command = input.command.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !command.isEmpty else {
            throw AgenticProcessesToolError.emptyCommand(
                toolName
            )
        }

        let policy =
            (try? context.require(Shell.CommandPolicy.self))
            ?? .standard

        return .init(
            policy: policy,
            command: command,
            workingDirectory: workspace.absoluteURL.standardizedFileURL,
            timeoutSeconds: try policy.timeoutSeconds(
                requested: input.timeoutSeconds,
                toolName: toolName
            )
        )
    }

    func tail(
        _ text: String,
        limit: Int
    ) -> (text: String, truncated: Bool) {
        guard text.count > limit else {
            return (text, false)
        }

        return (
            "[… truncated …]\n" + String(text.suffix(limit)),
            true
        )
    }
}

extension Shell.Tools.Run {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
        var facts: [ToolExecution.Projection.Fact] = [
            .init(label: "command", value: output.command),
            .init(label: "cwd", value: output.workingDirectory),
        ]
        if let exitCode = output.exitCode {
            facts.append(.init(label: "exit", value: String(exitCode)))
        }
        if let signal = output.signal {
            facts.append(.init(label: "signal", value: String(signal)))
        }
        if output.truncated {
            facts.append(.init(label: "output", value: "truncated to tail"))
        }
        return .init(
            status: output.succeeded ? "passed" : "failed",
            summary: output.command,
            facts: facts
        )
    }
}
