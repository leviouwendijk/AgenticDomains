import Agentic
import AgenticExecution
import Workspace
import Foundation
import SwiftSemantics

actor SwiftSemanticToolRuntime {
    static let shared = SwiftSemanticToolRuntime()

    private var workspaces: [
        URL: SwiftSemanticWorkspace
    ] = [:]

    func workspace(
        at root: URL
    ) -> SwiftSemanticWorkspace {
        let root = root.standardizedFileURL

        if let existing = workspaces[root] {
            return existing
        }

        let workspace = SwiftSemanticWorkspace(
            root: root
        )
        workspaces[root] = workspace
        return workspace
    }
}

struct SwiftSemanticToolContext {
    let workspace: WorkspaceContext
    let projectRoot: URL

    func projectFile(
        _ rawPath: String,
        toolName: String
    ) throws -> URL {
        let normalized = rawPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let components = normalized.split(
            separator: "/",
            omittingEmptySubsequences: false
        )

        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !components.contains("..")
        else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: toolName,
                operation: "resolve project-relative Swift source path",
                exitCode: nil,
                signal: nil,
                detail:
                    "Project-relative paths cannot be empty, absolute, or contain parent traversal: \(rawPath)"
            )
        }

        let candidate = projectRoot
            .appendingPathComponent(normalized)
            .standardizedFileURL
        let rootComponents = projectRoot
            .standardizedFileURL
            .pathComponents

        guard candidate.pathComponents.starts(with: rootComponents) else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: toolName,
                operation: "resolve project-relative Swift source path",
                exitCode: nil,
                signal: nil,
                detail: "Resolved source path escaped the selected Swift package root."
            )
        }

        return candidate
    }
}

enum SwiftSemanticToolSupport {
    static func resolve(
        _ context: WorkspaceContext?,
        toolName: String
    ) throws -> SwiftSemanticToolContext {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context,
            toolName: toolName
        )

        return .init(
            workspace: workspace,
            projectRoot: workspace.absoluteURL
        )
    }

    static func semanticWorkspace(
        for execution: SwiftSemanticToolContext
    ) async -> SwiftSemanticWorkspace {
        await SwiftSemanticToolRuntime.shared.workspace(
            at: execution.projectRoot
        )
    }

    static func position(
        line: Int,
        utf16Column: Int,
        toolName: String
    ) throws -> SwiftSemanticPosition {
        guard line > 0,
              utf16Column > 0
        else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: toolName,
                operation: "resolve compiler-semantic source position",
                exitCode: nil,
                signal: nil,
                detail:
                    "Compiler-semantic positions require positive one-based line and UTF-16 column values."
            )
        }

        return .init(
            line: line,
            utf16Column: utf16Column
        )
    }

    static func limit(
        _ requested: Int?,
        default defaultValue: Int = 100
    ) -> Int {
        max(
            1,
            requested
                ?? defaultValue
        )
    }

    static func preflight(
        context: WorkspaceContext?,
        toolName: String,
        risk: ActionRisk,
        path: String? = nil,
        usesCompilerProvider: Bool = true,
        summary: String
    ) throws -> ToolPreflight {
        let execution = try resolve(
            context,
            toolName: toolName
        )
        let targets: [String]

        if let path {
            targets = [
                try execution.projectFile(
                    path,
                    toolName: toolName
                ).path,
            ]
        } else {
            targets = [
                execution.projectRoot.path,
            ]
        }

        let sideEffects: [String]
        let warnings: [String]

        if usesCompilerProvider {
            sideEffects = [
                "May start a persistent sourcekit-lsp process for the selected Swift package.",
                "Semantic preparation may update SwiftPM or index state under .build.",
                "SwiftPM semantic preparation may execute package plugins or macros.",
            ]
            warnings = [
                "SourceKit-LSP semantic preparation is not guaranteed to be read-only even though the semantic query itself is observational."
            ]
        } else {
            sideEffects = [
                "SwiftPM package graph resolution may update dependency or checkout state under .build.",
            ]
            warnings = [
                "SwiftPM graph inspection can perform package-resolution preparation and is therefore reviewed conservatively."
            ]
        }

        return ToolPreflight(
            tool: ToolIdentifier(rawValue: toolName),
            risk: risk,
            summary: summary,
            access: .init(
                targets: targets
            ),
            estimates: .init(
                runtime: 60
            ),
            sideEffects: sideEffects,
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "project_relative_source_paths",
                usesCompilerProvider
                    ? "compiler_semantic_preparation_reviewed"
                    : "swift_package_graph_preparation_reviewed",
            ],
            warnings: warnings
        )
    }
}
