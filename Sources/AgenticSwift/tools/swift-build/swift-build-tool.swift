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

            /// Build mode for this run (sbm -d / --release). Omit for package.frame's .mode.
            /// Like every field here, it overrides only itself: the rest of package.frame applies.
            public let configuration: Configuration?
            /// Build only these executable products (sbm --products); replaces package.frame's
            /// selection. They deploy only when package.frame's .deploy lists them all, or with deploy.
            public let products: [String]?
            /// true deploys the selected products (sbm --deploy); false keeps them in .build
            /// (sbm -l). Omit to deploy exactly when package.frame's .deploy says so.
            public let deploy: Bool?
            /// Build from these fields alone, without package.frame (sbm --ignore-frame): no signing
            /// and no deploy unless asked.
            public let ignoreFrame: Bool?
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
                products: [String]? = nil,
                deploy: Bool? = nil,
                ignoreFrame: Bool? = nil,
                test: Bool? = nil,
                bench: Bool? = nil,
                cleanBefore: Bool? = nil,
                wipeBefore: Bool? = nil,
                clean: Bool? = nil,
                wipe: Bool? = nil
            ) {
                self.configuration = configuration
                self.products = products
                self.deploy = deploy
                self.ignoreFrame = ignoreFrame
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
        Build the current SwiftPM workspace the way sbm does: package.frame (.mode, .build, .sign, .deploy) with the given fields overriding it one by one (configuration = -d/--release, products = --products, deploy = --deploy/-l, ignoreFrame = --ignore-frame). Nothing deploys unless package.frame's .deploy or deploy: true says so; the preflight shows the equivalent sbm command and whether it deploys. The steps match sbm's flags: test runs the Tests/ primary first (a failure stops the build), bench the Benchmarks/ primary afterwards; cleanBefore/wipeBefore tidy the caches first, clean/wipe after a successful build; the steps' report is returned in steps.
        """

        public static let risk: ActionRisk = .privileged

        public init() {}
    }
}
