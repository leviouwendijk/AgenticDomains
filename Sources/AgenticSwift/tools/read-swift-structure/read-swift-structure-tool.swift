import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Position
import Primitives
import Schema

public struct ReadSwiftStructureTool: AgentTool {
    public typealias Input = ReadSwiftStructureToolInput
    public typealias Output = ReadSwiftStructureToolOutput
    public static let identifier: AgentToolIdentifier = "read_swift_structure"
    public static let description = "Read Swift declarations, types, members, imports, or the enclosing scope from a Swift source file in the workspace."
    public static let risk: ActionRisk = .observe

    public let selector: SwiftStructuralSelector

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init(
        selector: SwiftStructuralSelector = .init()
    ) {
        self.selector = selector
    }

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {

        _ = try input.structuralQuery()

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            input.path,
            workspace: context.workspace
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: context.workspace?.rootURL.path,
            targetPaths: [renderedPath],
            summary: summary(
                for: input,
                renderedPath: renderedPath
            )
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let query = try input.structuralQuery()
        let path = try workspace.resolve(
            input.path
        )

        let selections = try await selector.selections(
            in: path,
            query: query
        )
        let limitedSelections = Array(
            selections.prefix(
                input.clampedMaxMatches
            )
        )

        let matches = try limitedSelections.map { selection in
            let read = try workspace.readSlice(
                path,
                range: selection.lineRange
            )

            let content: String
            if let range = read.selectedLineRange {
                content = AgenticSwiftToolSupport.renderLines(
                    read.selectedLines,
                    startingAt: range.start,
                    includeLineNumbers: input.includeLineNumbers
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

        return ReadSwiftStructureToolOutput(
                path: path.presentingRelative(
                    filetype: true
                ),
                queryKind: input.queryKind.rawValue,
                matchCount: matches.count,
                matches: matches
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
    case operationFailed(
        toolName: String,
        operation: String,
        exitCode: Int?,
        signal: Int?,
        detail: String
    )

    var errorDescription: String? {
        switch self {
        case .workspaceRequired(let toolName):
            return "\(toolName) requires an attached AgentWorkspace."

        case .operationFailed(
            let toolName,
            let operation,
            let exitCode,
            let signal,
            let detail
        ):
            var summary = "\(toolName) failed while attempting to \(operation)."

            if let exitCode {
                summary += " Exit code: \(exitCode)."
            }

            if let signal {
                summary += " Signal: \(signal)."
            }

            let normalizedDetail = detail.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !normalizedDetail.isEmpty {
                summary += "\n\(normalizedDetail)"
            }

            return summary
        }
    }
}
