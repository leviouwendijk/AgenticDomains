import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

/// Configure a Swift package build invocation.


public struct SwiftBuildTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift build configuration.
        public enum Configuration:
            String,
            Sendable,
            Codable,
            Hashable,
            CaseIterable,
            JSONSchemaProviding
        {
            case debug
            case release

            public static var jsonschema: JSONSchema {
                .string(
                    cases: allCases.map(\.rawValue)
                )
            }
        }

        /// Optional explicit Swift build configuration. Omit to use the project default,
        /// including enabled build-object.pkl compile instructions.
        public let configuration:
            Configuration?

        public init(
            configuration:
                Configuration? = nil
        ) {
            self.configuration =
                configuration
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        public let configuration: String
        public let isSuccess: Bool
        public let exitCode: Int
        public let stdout: String
        public let stderr: String
        public let buildDirComponent: String

        public init(
            configuration: String,
            isSuccess: Bool,
            exitCode: Int,
            stdout: String,
            stderr: String,
            buildDirComponent: String
        ) {
            self.configuration =
                configuration
            self.isSuccess =
                isSuccess
            self.exitCode =
                exitCode
            self.stdout =
                stdout
            self.stderr =
                stderr
            self.buildDirComponent =
                buildDirComponent
        }
    }

public static let identifier:
        ToolIdentifier =
            "swift_build"

    public static let description =
        """
        Build the current SwiftPM workspace through Executable's typed Build.Request -> Build.resolve -> Build.execute workflow. Omit configuration to use normal sbm project defaults, including enabled build-object.pkl interception and deployment behavior. Explicit debug/release overrides do not deploy. Agentic disables built-version bookkeeping.
        """

    public static let risk:
        ActionRisk = .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

}

private extension SwiftBuildTool {
    func buildRequest(
        _ input: SwiftBuildTool.Input,
        workspace: WorkspaceContext
    ) throws -> Build.Request {
        guard let configuration = input.configuration else {
            return try SwiftBuildCommand.projectDefaultRequest(
                from: workspace.absoluteURL,
                updateBuiltOnSuccess: false
            )
        }

        let mode:
            Build.Config.Mode =
                switch configuration {
                case .debug:
                    .debug

                case .release:
                    .release
                }

        return Build.Request(
            project: workspace.absoluteURL,
            config: .init(
                mode: mode,
                updateBuiltOnSuccess: false
            ),
            deploy: false,
            source: .direct(
                arguments:
                    configuration == .debug
                        ? [
                            "--debug",
                        ]
                        : []
            )
        )
    }
}
