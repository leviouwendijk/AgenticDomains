import Agentic
import Foundation
import Path
import Position
import SwiftParser
import SwiftSyntax

public struct SwiftSymbolCollector: Sendable {
    public init() {}

    public func collect(
        in file: ScopedPath
    ) throws -> [SwiftSymbolSummary] {
        let relativePath = file.presentingRelative(
            filetype: true
        )

        guard relativePath.hasSuffix(".swift") else {
            throw SwiftStructuralSelectorError.unsupportedFile(
                relativePath
            )
        }

        let source = try String(
            contentsOf: absoluteURL(for: file),
            encoding: .utf8
        )
        let sourceFile = Parser.parse(
            source: source
        )
        let mapper = CollectorLineMapper(
            source: source
        )
        let visitor = SwiftSymbolVisitor(
            mapper: mapper
        )

        visitor.walk(sourceFile)

        return visitor.symbols()
    }
}

private extension SwiftSymbolCollector {
    func absoluteURL(
        for path: ScopedPath
    ) -> URL {
        URL(
            fileURLWithPath: path.absolute.render(
                as: .root,
                filetype: true
            ),
            isDirectory: false
        ).standardizedFileURL
    }
}

private struct CollectorLineMapper: Sendable {
    let utf8LineStarts: [Int]

    init(
        source: String
    ) {
        var starts: [Int] = [0]
        var offset = 0

        for scalar in source.unicodeScalars {
            offset += scalar.utf8.count

            if scalar == "\n" {
                starts.append(offset)
            }
        }

        self.utf8LineStarts = starts
    }

    func lineNumber(
        atUTF8Offset offset: Int
    ) -> Int {
        guard !utf8LineStarts.isEmpty else {
            return 1
        }

        var low = 0
        var high = utf8LineStarts.count - 1
        var best = 0

        while low <= high {
            let mid = (low + high) / 2
            let value = utf8LineStarts[mid]

            if value == offset {
                return mid + 1
            }

            if value < offset {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return best + 1
    }

    func lineRange(
        startUTF8Offset: Int,
        endUTF8Offset: Int
    ) -> LineRange? {
        let normalizedEnd = max(
            startUTF8Offset,
            endUTF8Offset - 1
        )

        let startLine = lineNumber(
            atUTF8Offset: startUTF8Offset
        )
        let endLine = lineNumber(
            atUTF8Offset: normalizedEnd
        )

        return try? .init(
            start: startLine,
            end: endLine
        )
    }
}

private final class SwiftSymbolVisitor: SyntaxVisitor {
    private let mapper: CollectorLineMapper

    private var collected: [SwiftSymbolSummary] = []
    private var typeStack: [String] = []

    init(
        mapper: CollectorLineMapper
    ) {
        self.mapper = mapper

        super.init(
            viewMode: .sourceAccurate
        )
    }

    func symbols() -> [SwiftSymbolSummary] {
        collected.sorted { lhs, rhs in
            if lhs.lineRange.start == rhs.lineRange.start {
                if lhs.lineRange.end == rhs.lineRange.end {
                    if lhs.kind == rhs.kind {
                        return lhs.displayName < rhs.displayName
                    }

                    return lhs.kind.rawValue < rhs.kind.rawValue
                }

                return lhs.lineRange.end < rhs.lineRange.end
            }

            return lhs.lineRange.start < rhs.lineRange.start
        }
    }

    override func visit(
        _ node: ImportDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .import,
            name: normalized(
                node.path.description
            ),
            parentType: nil,
            summary: normalized(
                node.description
            )
        )

        return .skipChildren
    }

    override func visit(
        _ node: StructDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .struct,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "struct \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: StructDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ClassDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .class,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "class \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ClassDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ActorDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .actor,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "actor \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ActorDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: EnumDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .enum,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "enum \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: EnumDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ProtocolDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .protocol,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "protocol \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ProtocolDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ExtensionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let name = normalized(
            node.extendedType.description
        )

        record(
            node,
            kind: .extension,
            name: name,
            parentType: nil,
            summary: "extension \(name)"
        )

        typeStack.append(name)

        return .visitChildren
    }

    override func visitPost(
        _ node: ExtensionDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: TypeAliasDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .typealias_decl,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "typealias \(node.name.text)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: FunctionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.function(
            node
        )

        record(
            node,
            kind: .function,
            name: node.name.text,
            displayName: displayName,
            parentType: currentTypeName,
            summary: "func \(displayName)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: InitializerDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.initializer(
            node
        )

        record(
            node,
            kind: .initializer,
            name: "init",
            displayName: displayName,
            parentType: currentTypeName,
            summary: displayName
        )

        return .visitChildren
    }

    override func visit(
        _ node: SubscriptDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.subscriptDecl(
            node
        )

        record(
            node,
            kind: .subscript_decl,
            name: "subscript",
            displayName: displayName,
            parentType: currentTypeName,
            summary: displayName
        )

        return .visitChildren
    }

    override func visit(
        _ node: VariableDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        guard let firstBinding = node.bindings.first else {
            return .visitChildren
        }

        record(
            node,
            kind: .variable,
            name: normalized(
                firstBinding.pattern.description
            ),
            parentType: currentTypeName,
            summary: "var \(normalized(firstBinding.pattern.description))"
        )

        return .visitChildren
    }

    override func visit(
        _ node: EnumCaseDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            record(
                node,
                kind: .enum_case,
                name: element.name.text,
                parentType: currentTypeName,
                summary: "case \(element.name.text)"
            )
        }

        return .visitChildren
    }
}

private extension SwiftSymbolVisitor {
    var currentTypeName: String? {
        typeStack.last
    }

    func record(
        _ node: some SyntaxProtocol,
        kind: SwiftSymbolKind,
        name: String,
        displayName: String? = nil,
        parentType: String?,
        summary: String
    ) {
        let startOffset = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let endOffset = node.endPositionBeforeTrailingTrivia.utf8Offset

        guard let lineRange = mapper.lineRange(
            startUTF8Offset: startOffset,
            endUTF8Offset: endOffset
        ) else {
            assertionFailure(
                "Failed to construct LineRange for Swift symbol collection."
            )
            return
        }

        collected.append(
            .init(
                kind: kind,
                name: name,
                displayName: displayName,
                parentType: parentType,
                lineRange: lineRange,
                summary: summary
            )
        )
    }

    func normalized(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
