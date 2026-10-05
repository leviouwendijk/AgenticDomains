import Agentic
import Macros
import Workspace
import Foundation
import Position
import SwiftSemantics
import Primitives
import Schema

public struct ReadSwiftStructureTool: Tool {
    @JSONSchema
    public struct Input: Sendable, Codable, Hashable {
        /// Semantic structure query kind.
        public enum QueryKind:
            String,
            Sendable,
            Codable,
            Hashable,
            CaseIterable,
            JSONSchemaProviding
        {
            case declaration
            case type
            case member
            case imports
            case enclosing_scope

            public static var jsonschema: JSONSchema {
                .string(
                    cases: allCases.map(\.rawValue)
                )
            }
        }

        /// Swift source file path relative to the current Agentic workspace.
        public let path: String

        /// Semantic structure query kind.
        public let queryKind: QueryKind

        /// Required for declaration, type, and member queries.
        public let name: String?

        /// Optional parent type used to disambiguate a member query.
        public let parentType: String?

        /// Required positive 1-based line for enclosing_scope.
        public let line: Int?

        /// Optional positive 1-based column for enclosing_scope.
        public let column: Int?

        /// Optional maximum number of matches. Defaults to 8 and is clamped to at least 1.
        public let maxMatches: Int?

        /// Whether returned source content includes line-number prefixes. Defaults to true.
        @Schema(required: false)
        public let includeLineNumbers: Bool

        public init(
            path: String,
            queryKind: QueryKind,
            name: String? = nil,
            parentType: String? = nil,
            line: Int? = nil,
            column: Int? = nil,
            maxMatches: Int? = nil,
            includeLineNumbers: Bool = true
        ) {
            self.path = path
            self.queryKind = queryKind
            self.name = name
            self.parentType = parentType
            self.line = line
            self.column = column
            self.maxMatches = maxMatches
            self.includeLineNumbers = includeLineNumbers
        }
    }

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        @JSONSchema
        public struct Match: Sendable, Codable, Hashable {
            public let kind: String
            public let symbolName: String?
            public let summary: String?
            public let lineRange: LineRange
            public let lineCount: Int
            public let content: String

            public init(
                kind: String,
                symbolName: String?,
                summary: String?,
                lineRange: LineRange,
                lineCount: Int,
                content: String
            ) {
                self.kind = kind
                self.symbolName = symbolName
                self.summary = summary
                self.lineRange = lineRange
                self.lineCount = lineCount
                self.content = content
            }
        }

        public let path: String
        public let queryKind: String
        public let matchCount: Int
        public let matches: [Match]

        public init(
            path: String,
            queryKind: String,
            matchCount: Int,
            matches: [Match]
        ) {
            self.path = path
            self.queryKind = queryKind
            self.matchCount = matchCount
            self.matches = matches
        }
    }

public static let identifier: ToolIdentifier = "read_swift_structure"
    public static let description = "Read Swift declarations, types, members, imports, or the enclosing scope from a Swift source file in the workspace."
    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public let selector: SwiftStructuralSelector

    public var identifier: ToolIdentifier {
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
        in context: ToolContext
    ) async throws -> ToolPreflight {

        _ = try input.structuralQuery()

        let renderedPath = try AgenticSwiftToolSupport.resolvedPreflightPath(
            input.path,
            workspace: context.workspace
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: summary(
                for: input,
                renderedPath: renderedPath
            ),
            access: .init(
                targets: [renderedPath]
            )
        )
    }

    public func call(
        _ input: Input,
        in context: ToolContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let query = try input.structuralQuery()
        let file = try AgenticSwiftToolSupport.projectFileURL(
            input.path,
            workspace: workspace,
            toolName: Self.definition.identifier.rawValue
        )

        let selections = try selector.selections(
            in: file,
            query: query
        )
        let limitedSelections = Array(
            selections.prefix(
                input.clampedMaxMatches
            )
        )

        let matches = try limitedSelections.map { selection in
            let read = try AgenticSwiftToolSupport.readLines(
                from: file,
                range: selection.lineRange
            )

            return Output.Match(
                kind: selection.kind.rawValue,
                symbolName: selection.symbolName,
                summary: selection.summary,
                lineRange: selection.lineRange,
                lineCount: read.lineCount,
                content: AgenticSwiftToolSupport.renderLines(
                    read.lines,
                    startingAt: read.startLine,
                    includeLineNumbers: input.includeLineNumbers
                )
            )
        }

        return Output(
            path: input.path,
            queryKind: input.queryKind.rawValue,
            matchCount: matches.count,
            matches: matches
        )
    }
}

private extension ReadSwiftStructureTool {
    func summary(
        for input: ReadSwiftStructureTool.Input,
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
        _ workspace: WorkspaceContext?,
        toolName: String
    ) throws -> WorkspaceContext {
        guard let workspace else {
            throw AgenticSwiftToolError.workspaceRequired(
                toolName
            )
        }

        return workspace
    }

    static func resolvedPreflightPath(
        _ rawPath: String,
        workspace: WorkspaceContext?
    ) throws -> String {
        guard let workspace else {
            return rawPath
        }

        return try projectFileURL(
            rawPath,
            workspace: workspace,
            toolName: "swift_source_path"
        ).path
    }

    static func projectFileURL(
        _ rawPath: String,
        workspace: WorkspaceContext,
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

        _ = try workspace.authorize(
            normalized,
            capability: .read
        )

        let candidate = workspace.absoluteURL
            .appendingPathComponent(normalized)
            .standardizedFileURL
        let rootComponents = workspace.absoluteURL
            .standardizedFileURL
            .pathComponents

        guard candidate.pathComponents.starts(with: rootComponents) else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: toolName,
                operation: "resolve project-relative Swift source path",
                exitCode: nil,
                signal: nil,
                detail:
                    "Resolved source path escaped the selected Swift package root."
            )
        }

        return candidate
    }

    static func readLines(
        from file: URL,
        range: LineRange
    ) throws -> (
        lineCount: Int,
        startLine: Int,
        lines: [String]
    ) {
        let source = try String(
            contentsOf: file,
            encoding: .utf8
        )
        var lines = source
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { line in
                var rendered = String(line)

                if rendered.last == "\r" {
                    rendered.removeLast()
                }

                return rendered
            }

        if source.hasSuffix("\n"),
           lines.last == "" {
            lines.removeLast()
        }

        let lineCount = lines.count
        let start = max(
            1,
            range.start
        )
        let end = min(
            lineCount,
            range.end
        )

        guard start <= end else {
            return (
                lineCount: lineCount,
                startLine: start,
                lines: []
            )
        }

        return (
            lineCount: lineCount,
            startLine: start,
            lines: Array(
                lines[(start - 1)...(end - 1)]
            )
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
            return "\(toolName) requires an attached WorkspaceContext."

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

/// Read a semantic Swift structure from one source file.
/// declaration/type/member require name.
/// member optionally accepts parentType.
/// enclosing_scope requires a positive 1-based line and optionally a positive 1-based column.
/// imports needs no additional query fields.

private extension ReadSwiftStructureTool.Input {
    enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case queryKind
        case name
        case parentType
        case line
        case column
        case maxMatches
        case includeLineNumbers
    }
}

public extension ReadSwiftStructureTool.Input {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            path: try container.decode(
                String.self,
                forKey: .path
            ),
            queryKind: try container.decode(
                QueryKind.self,
                forKey: .queryKind
            ),
            name: try container.decodeIfPresent(
                String.self,
                forKey: .name
            ),
            parentType: try container.decodeIfPresent(
                String.self,
                forKey: .parentType
            ),
            line: try container.decodeIfPresent(
                Int.self,
                forKey: .line
            ),
            column: try container.decodeIfPresent(
                Int.self,
                forKey: .column
            ),
            maxMatches: try container.decodeIfPresent(
                Int.self,
                forKey: .maxMatches
            ),
            includeLineNumbers: try container.decodeIfPresent(
                Bool.self,
                forKey: .includeLineNumbers
            ) ?? true
        )
    }
}

public extension ReadSwiftStructureTool.Input {


    func structuralQuery() throws -> SwiftSemanticStructureQuery {
        switch queryKind {
        case .declaration:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .declaration(
                named: name
            )

        case .type:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .type(
                named: name
            )

        case .member:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .member(
                named: name,
                parentType: parentType
            )

        case .imports:
            return .imports

        case .enclosing_scope:
            guard let line,
                  line > 0 else {
                throw SwiftStructuralSelectorError.invalidLocation(
                    line: line ?? 0,
                    column: column
                )
            }

            if let column,
               column <= 0 {
                throw SwiftStructuralSelectorError.invalidLocation(
                    line: line,
                    column: column
                )
            }

            return .enclosingScope(
                location: .init(
                    line: line,
                    column: column
                )
            )
        }
    }

    var clampedMaxMatches: Int {
        guard let maxMatches else {
            return 8
        }

        return max(1, maxMatches)
    }
}
