import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

/// What to run from a test or benchmark package (at most one of all, live, group and
/// product; none runs the primary), and how to tidy its caches around the run.
@JSONSchema
public struct SwiftTestRunInput:
    Sendable,
    Codable,
    Hashable
{
    /// Run every product except the interactive and live ones.
    public let all: Bool?
    /// Run the live products: they reach real services (network, credentials).
    public let live: Bool?
    /// A named group from the package's package.frame.
    public let group: String?
    /// One product by name.
    public let product: String?
    /// swift package clean in the packages it runs in, before the run.
    public let cleanBefore: Bool?
    /// Delete their .build and .index-build before the run (keep list applies); replaces cleanBefore.
    public let wipeBefore: Bool?
    /// swift package clean after a successful run.
    public let clean: Bool?
    /// Delete .build and .index-build after a successful run; replaces clean. Without it, a
    /// package.frame .wipe.above still wipes caches that grew past its size.
    public let wipe: Bool?

    public init(
        all: Bool? = nil,
        live: Bool? = nil,
        group: String? = nil,
        product: String? = nil,
        cleanBefore: Bool? = nil,
        wipeBefore: Bool? = nil,
        clean: Bool? = nil,
        wipe: Bool? = nil
    ) {
        self.all = all
        self.live = live
        self.group = group
        self.product = product
        self.cleanBefore = cleanBefore
        self.wipeBefore = wipeBefore
        self.clean = clean
        self.wipe = wipe
    }
}

/// One product's run.
@JSONSchema
public struct SwiftTestProductResult:
    Sendable,
    Codable,
    Hashable
{
    public let product: String
    /// The nested package the product ran in (Tests/, Benchmarks/).
    public let package: String
    public let mode: String
    public let isSuccess: Bool
    public let exitCode: Int32?
    public let signal: Int32?
    /// The end of standard output.
    public let stdout: String
    /// The end of standard error.
    public let stderr: String

    public init(
        product: String,
        package: String,
        mode: String,
        isSuccess: Bool,
        exitCode: Int32?,
        signal: Int32?,
        stdout: String,
        stderr: String
    ) {
        self.product = product
        self.package = package
        self.mode = mode
        self.isSuccess = isSuccess
        self.exitCode = exitCode
        self.signal = signal
        self.stdout = stdout
        self.stderr = stderr
    }
}

@JSONSchema
public struct SwiftTestRunOutput:
    Sendable,
    Codable,
    Hashable
{
    public let isSuccess: Bool
    public let results: [SwiftTestProductResult]
    /// What the clean and wipe steps reported (the end, when long); nil when none ran.
    public let steps: String?

    public init(
        isSuccess: Bool,
        results: [SwiftTestProductResult],
        steps: String? = nil
    ) {
        self.isSuccess = isSuccess
        self.results = results
        self.steps = steps
    }
}

public extension SwiftLang.Tools {
    @Tool("test")
    struct RunTests {
        public typealias Input = SwiftTestRunInput
        public typealias Output = SwiftTestRunOutput

        public static let purpose =
            """
            Run the test products of the workspace's Tests/ package through the Executable library, the same resolution `sbm test` uses (the sbm binary itself is not needed). Requires the package.frame convention: a nested directory with Package.swift and a package.frame declaring `let tests: Tests` (Tests/ by convention), or an unsplit project's Tests/package.frame; anything else fails with "No test package". The frame selects the primary, a group, one product, the live products (live: true; real services, network, credentials) or all products that are neither interactive nor live; tests build in debug unless it sets .mode. cleanBefore/wipeBefore tidy the test package's caches first; clean/wipe after a successful run, the same as `sbm test --clean --wipe`. Products in the root package are run with swift_tool_run_product instead. Failures are returned as results, not errors.
            """

        public static let risk: ActionRisk = .privileged

        public init() {}
    }

    @Tool("bench")
    struct RunBenchmarks {
        public typealias Input = SwiftTestRunInput
        public typealias Output = SwiftTestRunOutput

        public static let purpose =
            """
            Run the benchmark products of the workspace's Benchmarks/ package through the Executable library, the same resolution `sbm bench` uses (the sbm binary itself is not needed). Requires a nested directory with Package.swift and a package.frame declaring `let benchmarks: Benchmarks` (Benchmarks/ by convention); without one it fails with "No benchmark package". Release builds unless the frame sets .mode; same selection and clean/wipe steps as swift_tool_test.
            """

        public static let risk: ActionRisk = .privileged

        public init() {}
    }
}

extension SwiftLang.Tools.RunTests {
    public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
        try await SwiftTestToolSupport.preflight(input, kind: .tests, tool: Self.definition.identifier, risk: risk, context: context)
    }

    public func call(_ input: Input, in context: ToolContext) async throws -> Output {
        try await SwiftTestToolSupport.run(input, kind: .tests, toolName: Self.definition.identifier.rawValue, context: context)
    }

    public func process(_ output: Output, input _: Input) -> ToolExecution.Projection? {
        SwiftTestToolSupport.projection(output, noun: "test")
    }
}

extension SwiftLang.Tools.RunBenchmarks {
    public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
        try await SwiftTestToolSupport.preflight(input, kind: .benchmarks, tool: Self.definition.identifier, risk: risk, context: context)
    }

    public func call(_ input: Input, in context: ToolContext) async throws -> Output {
        try await SwiftTestToolSupport.run(input, kind: .benchmarks, toolName: Self.definition.identifier.rawValue, context: context)
    }

    public func process(_ output: Output, input _: Input) -> ToolExecution.Projection? {
        SwiftTestToolSupport.projection(output, noun: "benchmark")
    }
}

enum SwiftTestToolSupport {
    static func selection(_ input: SwiftTestRunInput, toolName: String) throws -> TestConfiguration.Selection {
        let chosen = [input.all == true, input.live == true, input.group != nil, input.product != nil].filter { $0 }.count
        guard chosen <= 1 else {
            throw AgenticSwiftToolError.invalidInput(
                toolName: toolName,
                detail: "Choose at most one of all, live, group and product."
            )
        }
        if input.all == true { return .all }
        if input.live == true { return .live }
        if let group = input.group { return .group(group) }
        if let product = input.product { return .product(product) }
        return .primary
    }

    static func preflight(
        _ input: SwiftTestRunInput,
        kind: Tests.Kind,
        tool: ToolIdentifier,
        risk: ActionRisk,
        context: ToolContext
    ) async throws -> ToolPreflight {
        let toolName = tool.rawValue
        let execution = try SwiftWorkspaceExecution.resolve(context.workspace, toolName: toolName)
        let plan = try await Tests.resolve(
            at: execution.projectRoot,
            selection: try selection(input, toolName: toolName),
            kind: kind
        )
        let commands = plan.runs.flatMap { run in
            run.products.map { product in
                "swift run --package-path \(run.package.lastPathComponent)\(run.mode == .release ? " -c release" : "") \(product)"
            }
        }
        return ToolPreflight(
            tool: tool,
            risk: risk,
            summary: "Run \(plan.products.count) \(kind == .tests ? "test" : "benchmark") product(s): \(plan.products.joined(separator: ", ")).",
            access: .init(targets: plan.runs.map { $0.package.appendingPathComponent(".build", isDirectory: true).path }),
            estimates: .init(write: .init(count: plan.runs.count), runtime: kind == .tests ? 600 : 1800),
            preview: .init(commands.map { .command(.init($0)) }),
            sideEffects: SwiftTidySteps(input).sideEffects + [
                "Builds the selected products under the nested package's .build before running them.",
                "Executes repository-owned code with the current host filesystem, process, environment, and network permissions.",
                "Execution is managed by Processes with an output limit and timeout.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "package_frame_selection",
                "parent_graph_checked",
                "no_model_supplied_process_arguments",
                "managed_process_execution",
                "human_review_required",
            ],
            warnings: [
                "Executed repository code is not confined by Agentic PathSandbox."
            ]
        )
    }

    static func run(
        _ input: SwiftTestRunInput,
        kind: Tests.Kind,
        toolName: String,
        context: ToolContext
    ) async throws -> SwiftTestRunOutput {
        let execution = try SwiftWorkspaceExecution.resolve(context.workspace, toolName: toolName)
        let plan = try await Tests.resolve(
            at: execution.projectRoot,
            selection: try selection(input, toolName: toolName),
            kind: kind
        )
        let tidy = SwiftTidySteps(input)
        var packages: [URL] = []
        for run in plan.runs where !packages.contains(run.package) {
            packages.append(run.package)
        }
        try await tidy.before(packages)
        var results: [SwiftTestProductResult] = []
        for run in plan.runs {
            for product in run.products {
                let result = try await SwiftRun.run(
                    .init(product: product, mode: run.mode),
                    at: run.package,
                    options: .init(
                        outputLimit: 4 * 1024 * 1024,
                        timeout: .seconds(kind == .tests ? 600 : 1800)
                    )
                )
                results.append(.init(
                    product: product,
                    package: run.package.lastPathComponent,
                    mode: run.mode == .release ? "release" : "debug",
                    isSuccess: result.isSuccess,
                    exitCode: result.exitCode,
                    signal: result.signal,
                    stdout: String(result.stdoutText.suffix(12_288)),
                    stderr: String(result.stderrText.suffix(4_096))
                ))
            }
        }
        let isSuccess = results.allSatisfy(\.isSuccess)
        if isSuccess {
            try await tidy.after(packages)
        }
        return .init(isSuccess: isSuccess, results: results, steps: tidy.report)
    }

    static func projection(_ output: SwiftTestRunOutput, noun: String) -> ToolExecution.Projection {
        let failed = output.results.filter { !$0.isSuccess }.map(\.product)
        var facts: [ToolExecution.Projection.Fact] = [
            .init(label: "products", value: output.results.map(\.product).joined(separator: ", ")),
        ]
        if !failed.isEmpty {
            facts.append(.init(label: "failed", value: failed.joined(separator: ", ")))
        }
        return .init(
            status: output.isSuccess ? "passed" : "failed",
            summary: output.isSuccess
                ? "All \(output.results.count) \(noun) product(s) passed."
                : "\(failed.count) of \(output.results.count) \(noun) product(s) failed.",
            facts: facts
        )
    }
}
