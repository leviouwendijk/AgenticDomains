import Agentic
import AgenticWorkspace
import Foundation
import Path
import SwiftSemantics

/// Agentic compatibility adapter over SwiftSemantics structural selection.
///
/// Structural query vocabulary remains model-facing in AgenticSwift for
/// compatibility, while SwiftSemantics owns SwiftSyntax parsing and selection.
public struct SwiftStructuralSelector:
    StructuralSelector
{
    private let inspector: SwiftSemanticStructureInspector

    public init(
        inspector: SwiftSemanticStructureInspector = .init()
    ) {
        self.inspector = inspector
    }

    public func selections(
        in file: DescendantPath,
        query: StructuralQuery
    ) async throws -> [StructuralSelection] {
        switch query {
        case .lines(let lineRange):
            return [
                StructuralSelection(
                    path: file,
                    lineRange: lineRange,
                    kind: .lines
                ),
            ]

        case .declaration(let name):
            return try semanticSelections(
                in: file,
                query: .declaration(
                    named: name
                )
            )

        case .type(let name):
            return try semanticSelections(
                in: file,
                query: .type(
                    named: name
                )
            )

        case .member(
            let name,
            let parentType
        ):
            return try semanticSelections(
                in: file,
                query: .member(
                    named: name,
                    parentType: parentType
                )
            )

        case .imports:
            return try semanticSelections(
                in: file,
                query: .imports
            )

        case .enclosingScope(let location):
            return try semanticSelections(
                in: file,
                query: .enclosingScope(
                    location: .init(
                        line: location.line,
                        column: location.column
                    )
                )
            )
        }
    }
}

private extension SwiftStructuralSelector {
    func absoluteURL(
        for path: DescendantPath
    ) -> URL {
        URL(
            fileURLWithPath: path.absolute.render(
                as: .root,
                filetype: true
            ),
            isDirectory: false
        )
        .standardizedFileURL
    }

    func semanticSelections(
        in file: DescendantPath,
        query: SwiftSemanticStructureQuery
    ) throws -> [StructuralSelection] {
        try inspector.selections(
            in: absoluteURL(
                for: file
            ),
            query: query
        )
        .map { selection in
            StructuralSelection(
                path: file,
                lineRange: selection.lineRange,
                kind: structuralKind(
                    selection.kind
                ),
                symbolName: selection.symbolName,
                summary: selection.summary
            )
        }
    }

    func structuralKind(
        _ kind: SwiftSemanticStructureSelection.Kind
    ) -> StructuralSelection.Kind {
        switch kind {
        case .declaration:
            return .declaration
        case .type:
            return .type
        case .member:
            return .member
        case .imports:
            return .imports
        case .enclosing_scope:
            return .enclosingScope
        }
    }
}
