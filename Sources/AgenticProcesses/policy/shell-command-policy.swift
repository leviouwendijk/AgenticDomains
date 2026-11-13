import Agentic
import Foundation
import Processes

public extension Shell {
    /// Trusted, host-injected policy for shell execution.
    /// Inject through ToolServices; without one, `.standard` applies and every command is privileged.
    struct CommandPolicy:
        Sendable
    {
        public let shell: String
        public let environment: ProcessEnvironment
        public let boundedPrograms: Set<String>
        public let defaultTimeoutSeconds: Int
        public let maximumTimeoutSeconds: Int
        public let outputLimit: Int
        public let resultCharacterLimit: Int

        public init(
            shell: String = "/bin/zsh",
            environment: ProcessEnvironment = .inherited,
            boundedPrograms: Set<String> = [],
            defaultTimeoutSeconds: Int = 120,
            maximumTimeoutSeconds: Int = 600,
            outputLimit: Int = 16 * 1024 * 1024,
            resultCharacterLimit: Int = 30_000
        ) {
            self.shell = shell
            self.environment = environment
            self.boundedPrograms = boundedPrograms
            self.defaultTimeoutSeconds = defaultTimeoutSeconds
            self.maximumTimeoutSeconds = maximumTimeoutSeconds
            self.outputLimit = outputLimit
            self.resultCharacterLimit = resultCharacterLimit
        }

        public static let standard = Self()
    }
}

public extension Shell.CommandPolicy {
    /// Characters that let one command line run, chain, redirect or expand into something else.
    static let metacharacters: Set<Character> = [
        ";", "&", "|", "`", "$", "(", ")", "{", "}",
        "<", ">", "*", "?", "[", "]", "~", "!", "#",
        "\\", "'", "\"", "\n", "\r",
    ]

    /// Never `.observe`: a command is `.boundedmutate` only when it is a plain
    /// invocation of a host-allowlisted program; everything else is `.privileged`.
    func risk(
        for command: String
    ) -> ActionRisk {
        guard let program = boundedProgram(for: command) else {
            return .privileged
        }

        return boundedPrograms.contains(program)
            ? .boundedmutate
            : .privileged
    }

    func boundedProgram(
        for command: String
    ) -> String? {
        guard !command.contains(where: Self.metacharacters.contains) else {
            return nil
        }

        return command
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
    }

    func timeoutSeconds(
        requested: Int?,
        toolName: String
    ) throws -> Int {
        let seconds = requested ?? defaultTimeoutSeconds

        guard seconds <= maximumTimeoutSeconds else {
            throw AgenticProcessesToolError.timeoutExceedsMaximum(
                toolName: toolName,
                requested: seconds,
                maximum: maximumTimeoutSeconds
            )
        }

        return max(1, seconds)
    }
}
