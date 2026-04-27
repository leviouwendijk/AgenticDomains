import Agentic
import Foundation
import Position
import Primitives

public struct ReadSwiftStructureTool: StaticAgentTool {
    public static let identifier: AgentToolIdentifier = "read_swift_structure"
    public static let description = "Read Swift declarations, types, members, imports, or the enclosing scope from a Swift source file in the workspace."
    public static let risk: ActionRisk = .observe

    public let selector: SwiftStructuralSelector

    public init(
        selector: SwiftStructuralSelector = .init()
    ) {
        self.selector = selector
    }

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            ReadSwiftStructureToolInput.self,
            from: input
        )

        _ = try decoded.structuralQuery()

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            decoded.path,
            workspace: workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace?.rootURL.path,
            targetPaths: [renderedPath],
            summary: summary(
                for: decoded,
                renderedPath: renderedPath
            )
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let decoded = try JSONToolBridge.decode(
            ReadSwiftStructureToolInput.self,
            from: input
        )
        let query = try decoded.structuralQuery()
        let scopedPath = try workspace.resolve(
            decoded.path
        )

        let selections = try await selector.selections(
            in: scopedPath,
            query: query
        )
        let limitedSelections = Array(
            selections.prefix(
                decoded.clampedMaxMatches
            )
        )

        let matches = try limitedSelections.map { selection in
            let read = try workspace.readSlice(
                scopedPath,
                range: selection.lineRange
            )

            let content: String
            if let range = read.selectedLineRange {
                content = AgenticSwiftToolSupport.renderLines(
                    read.selectedLines,
                    startingAt: range.start,
                    includeLineNumbers: decoded.includeLineNumbers
                )
            } else {
                content = ""
            }

            return ReadSwiftStructureToolOutput.Match(
                kind: selection.kind.rawValue,
                symbolName: selection.symbolName,
                summary: selection.summary,
                lineRange: selection.lineRange,
                lineCount: read.lineCount,
                content: content
            )
        }

        return try JSONToolBridge.encode(
            ReadSwiftStructureToolOutput(
                path: scopedPath.presentingRelative(
                    filetype: true
                ),
                queryKind: decoded.queryKind.rawValue,
                matchCount: matches.count,
                matches: matches
            )
        )
    }
}

private extension ReadSwiftStructureTool {
    func summary(
        for input: ReadSwiftStructureToolInput,
        renderedPath: String
    ) -> String {
        switch input.queryKind {
        case .declaration:
            return "Read Swift declaration '\(input.name ?? "")' in \(renderedPath)"

        case .type:
            return "Read Swift type '\(input.name ?? "")' in \(renderedPath)"

        case .member:
            if let parentType = input.parentType,
               !parentType.isEmpty {
                return "Read Swift member '\(input.name ?? "")' in \(parentType) from \(renderedPath)"
            }

            return "Read Swift member '\(input.name ?? "")' in \(renderedPath)"

        case .imports:
            return "Read Swift imports from \(renderedPath)"

        case .enclosing_scope:
            if let column = input.column {
                return "Read enclosing Swift scope at \(renderedPath):\(input.line ?? 0):\(column)"
            }

            return "Read enclosing Swift scope at \(renderedPath):\(input.line ?? 0)"
        }
    }
}

enum AgenticSwiftToolSupport {
    static func requireWorkspace(
        _ workspace: AgentWorkspace?,
        toolName: String
    ) throws -> AgentWorkspace {
        guard let workspace else {
            throw AgenticSwiftToolError.workspaceRequired(
                toolName
            )
        }

        return workspace
    }

    static func resolvedPreflightPath(
        _ rawPath: String,
        workspace: AgentWorkspace?
    ) throws -> String {
        guard let workspace else {
            return rawPath
        }

        return try workspace.resolve(
            rawPath
        ).presentingRelative(
            filetype: true
        )
    }

    static func renderLines(
        _ lines: [String],
        startingAt firstLine: Int,
        includeLineNumbers: Bool
    ) -> String {
        guard includeLineNumbers else {
            return lines.joined(
                separator: "\n"
            )
        }

        return lines.enumerated().map { index, line in
            "\(firstLine + index) | \(line)"
        }.joined(separator: "\n")
    }
}

enum AgenticSwiftToolError: Error, Sendable, LocalizedError {
    case workspaceRequired(String)

    var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return "\(toolName) requires an attached AgentWorkspace."
        }
    }
}
