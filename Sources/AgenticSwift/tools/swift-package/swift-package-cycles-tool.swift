import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

public struct SwiftPackageCyclesTool: Tool {
    @JSONSchema
    public struct Input:
        Codable,
        Sendable
    {
        public init() {}
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        @JSONSchema
        public struct Cycle:
            Sendable,
            Codable,
            Hashable
        {
            public let packages: [String]
            public let rendered: String

            public init(
                packages: [String],
                rendered: String
            ) {
                self.packages = packages
                self.rendered = rendered
            }
        }

        public let root: String
        public let packageCount: Int
        public let hasCycles: Bool
        public let cycles: [Cycle]
        public let unreadableManifests: [String]

        public init(
            root: String,
            packageCount: Int,
            hasCycles: Bool,
            cycles: [Cycle],
            unreadableManifests: [String]
        ) {
            self.root = root
            self.packageCount = packageCount
            self.hasCycles = hasCycles
            self.cycles = cycles
            self.unreadableManifests = unreadableManifests
        }
    }

    public static let identifier: ToolIdentifier = "swift_package_cycles"
    public static let description =
        "Detect package-level dependency cycles for the selected Swift package through Executable.SwiftPackageCycles. Evaluates each manifest on its own with swift package dump-package (the root package and every checkout under .build/checkouts) and walks the graph itself, so it still works when a cycle makes SwiftPM crash while walking the graph (for example inspect_package_graph failing with exit 138)."
    public static let risk: ActionRisk = .observe

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

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let project = workspace.absoluteURL

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Scan declared package dependencies at the selected workspace location for cycles.",
            access: .init(
                targets: [
                    project.appendingPathComponent("Package.swift").path,
                    project
                        .appendingPathComponent(
                            ".build",
                            isDirectory: true
                        )
                        .appendingPathComponent(
                            "checkouts",
                            isDirectory: true
                        )
                        .path,
                ]
            ),
            estimates: .init(
                runtime: 120
            ),
            preview: .init(
                command: "swift package dump-package (per package)"
            ),
            sideEffects: [
                "Evaluates the root manifest and each checked-out dependency manifest through SwiftPM."
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "swift_package_introspection",
                "no_package_graph_resolution",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let report = try await SwiftPackageCycles.scan(
            packageDirectory: workspace.absoluteURL
        )

        return Output(
            root: report.root,
            packageCount: report.packages.count,
            hasCycles: report.hasCycles,
            cycles: report.cycles.map { cycle in
                .init(
                    packages: cycle,
                    rendered: (cycle + cycle.prefix(1)).joined(separator: " -> ")
                )
            },
            unreadableManifests: report.unreadableManifests
        )
    }

    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        var facts: [ToolCall.ResultProjection.Fact] = [
            .init(label: "root", value: output.root),
            .init(label: "packages", value: "\(output.packageCount)"),
            .init(label: "cycles", value: "\(output.cycles.count)"),
        ]

        if let first = output.cycles.first {
            facts.append(.init(label: "first cycle", value: first.rendered))
        }

        return .init(
            status: "passed",
            summary: output.hasCycles
                ? "Found \(output.cycles.count) package dependency cycle(s)."
                : "No package dependency cycles were found.",
            facts: facts
        )
    }
}
