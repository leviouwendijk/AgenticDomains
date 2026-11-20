import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

/// Configure a Swift package build invocation.
public extension SwiftLang.Tools {
    @Tool("swift_build")
    struct Build {
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
            /// including package.frame .build and .deploy.
            public let configuration: Configuration?
            /// Run the Tests/ primary first; a failure stops the build and its deployment.
            public let test: Bool?
            /// Run the Benchmarks/ primary after a successful build.
            public let bench: Bool?
            /// swift package clean first (the package, plus Tests/ and Benchmarks/ when they run).
            public let cleanBefore: Bool?
            /// Delete .build and .index-build first, for a fresh build (keep list applies); replaces cleanBefore.
            public let wipeBefore: Bool?
            /// swift package clean after a successful build.
            public let clean: Bool?
            /// Delete .build and .index-build after a successful build; replaces clean. Without it, a
            /// package.frame .wipe.above still wipes caches that grew past its size.
            public let wipe: Bool?

            public init(
                configuration: Configuration? = nil,
                test: Bool? = nil,
                bench: Bool? = nil,
                cleanBefore: Bool? = nil,
                wipeBefore: Bool? = nil,
                clean: Bool? = nil,
                wipe: Bool? = nil
            ) {
                self.configuration = configuration
                self.test = test
                self.bench = bench
                self.cleanBefore = cleanBefore
                self.wipeBefore = wipeBefore
                self.clean = clean
                self.wipe = wipe
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
            /// What the test, benchmark, clean and wipe steps reported (the end, when long);
            /// nil when none ran.
            public let steps: String?

            public init(
                configuration: String,
                isSuccess: Bool,
                exitCode: Int,
                stdout: String,
                stderr: String,
                buildDirComponent: String,
                steps: String? = nil
            ) {
                self.steps =
                    steps
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

        public static let purpose = """
        Build the current SwiftPM workspace through Executable's typed Build.Request -> Build.resolve -> Build.execute workflow. Omit configuration to use normal sbm project defaults, including package.frame .build and .deploy and deployment behavior. Explicit debug/release overrides do not deploy. Agentic disables built-version bookkeeping. The steps match sbm's flags: test runs the Tests/ primary first (a failure stops the build), bench the Benchmarks/ primary afterwards; cleanBefore/wipeBefore tidy the caches first, clean/wipe after a successful build; the steps' report is returned in steps.
        """

        public static let risk: ActionRisk = .privileged

        public init() {}
    }
}

private extension SwiftLang.Tools.Build {
    func buildRequest(
        _ input: SwiftLang.Tools.Build.Input,
        workspace: WorkspaceContext
    ) throws -> Executable.Build.Request {
        guard let configuration = input.configuration else {
            return try SwiftBuildCommand.projectDefaultRequest(
                from: workspace.absoluteURL
            )
        }

        let mode:
            Executable.Build.Config.Mode =
                switch configuration {
                case .debug:
                    .debug

                case .release:
                    .release
                }

        return Executable.Build.Request(
            project: workspace.absoluteURL,
            config: .init(
                mode: mode
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
