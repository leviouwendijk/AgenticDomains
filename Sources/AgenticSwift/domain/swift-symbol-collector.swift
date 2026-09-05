import Foundation
import Path
import SwiftSemantics

/// Agentic compatibility projection over SwiftSemantics structural symbols.
///
/// AgenticSwift keeps its established model-facing SwiftSymbolSummary surface,
/// while SwiftSemantics owns Swift parsing and structural source understanding.
public struct SwiftSymbolCollector:
    Sendable
{
    private let collector: SwiftSemanticSymbolCollector

    public init(
        collector: SwiftSemanticSymbolCollector = .init()
    ) {
        self.collector = collector
    }

    public func collect(
        in file: DescendantPath
    ) throws -> [SwiftSymbolSummary] {
        try collector.collect(
            in: absoluteURL(
                for: file
            )
        )
        .map { symbol in
            SwiftSymbolSummary(
                kind: SwiftSymbolKind(
                    semantic: symbol.kind
                ),
                name: symbol.name,
                displayName: symbol.displayName,
                parentType: symbol.parentType,
                lineRange: symbol.lineRange,
                summary: symbol.summary
            )
        }
    }
}

private extension SwiftSymbolCollector {
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
}

private extension SwiftSymbolKind {
    init(
        semantic kind: SwiftSemanticSymbolKind
    ) {
        switch kind {
        case .import:
            self = .import
        case .struct:
            self = .struct
        case .class:
            self = .class
        case .actor:
            self = .actor
        case .enum:
            self = .enum
        case .protocol:
            self = .protocol
        case .extension:
            self = .extension
        case .typealias_decl:
            self = .typealias_decl
        case .function:
            self = .function
        case .initializer:
            self = .initializer
        case .subscript_decl:
            self = .subscript_decl
        case .variable:
            self = .variable
        case .enum_case:
            self = .enum_case
        }
    }
}
