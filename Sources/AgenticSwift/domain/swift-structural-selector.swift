import Agentic
import Foundation
import Path
import Position
import SwiftParser
import SwiftSyntax

public struct SwiftStructuralSelector: StructuralSelector {
    public init() {}

    public func selections(
        in file: ScopedPath,
        query: StructuralQuery
    ) async throws -> [StructuralSelection] {
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
        let mapper = SourceLineMapper(
            source: source
        )
        let visitor = SwiftStructureVisitor(
            path: file,
            query: query,
            mapper: mapper
        )

        visitor.walk(sourceFile)

        return visitor.matches()
    }
}

private extension SwiftStructuralSelector {
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

private struct SourceLineMapper: Sendable {
    let source: String
    let utf8LineStarts: [Int]

    init(
        source: String
    ) {
        self.source = source

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

private struct StructuralMatch: Sendable {
    let selection: StructuralSelection
    let startUTF8Offset: Int
    let endUTF8Offset: Int
}

private final class SwiftStructureVisitor: SyntaxVisitor {
    private let path: ScopedPath
    private let query: StructuralQuery
    private let mapper: SourceLineMapper

    private var collected: [StructuralMatch] = []
    private var typeStack: [String] = []

    init(
        path: ScopedPath,
        query: StructuralQuery,
        mapper: SourceLineMapper
    ) {
        self.path = path
        self.query = query
        self.mapper = mapper

        super.init(
            viewMode: .sourceAccurate
        )
    }

    func matches() -> [StructuralSelection] {
        switch query {
        case .enclosingScope(let location):
            let containing = collected.filter { match in
                match.selection.lineRange.start <= location.line
                    && match.selection.lineRange.end >= location.line
            }

            guard let smallest = containing.min(
                by: isNarrower(lhs:rhs:)
            ) else {
                return []
            }

            return [smallest.selection]

        default:
            return collected.map(\.selection)
        }
    }

    override func visit(
        _ node: StructDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        recordType(
            node,
            kind: .type,
            name: node.name.text,
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
        recordType(
            node,
            kind: .type,
            name: node.name.text,
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
        recordType(
            node,
            kind: .type,
            name: node.name.text,
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
        recordType(
            node,
            kind: .type,
            name: node.name.text,
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
        recordType(
            node,
            kind: .type,
            name: node.name.text,
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

        recordAnyDeclaration(
            node,
            kind: .declaration,
            name: name,
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
        recordAnyDeclaration(
            node,
            kind: currentTypeName == nil ? .declaration : .member,
            name: node.name.text,
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

        recordMemberLike(
            node,
            name: node.name.text,
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

        recordMemberLike(
            node,
            name: "init",
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

        recordMemberLike(
            node,
            name: "subscript",
            summary: displayName
        )

        return .visitChildren
    }

    override func visit(
        _ node: VariableDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let name = variableName(
            from: node
        )

        recordMemberLike(
            node,
            name: name,
            summary: "var \(name)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: EnumCaseDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let name = node.elements.first?.name.text
            ?? "case"

        recordMemberLike(
            node,
            name: name,
            summary: "case \(name)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: ImportDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        if case .imports = query {
            record(
                node,
                kind: .imports,
                name: nil,
                summary: normalized(
                    node.description
                )
            )
        }

        return .skipChildren
    }
}

private extension SwiftStructureVisitor {
    var currentTypeName: String? {
        typeStack.last
    }

    func recordType(
        _ node: some SyntaxProtocol,
        kind: StructuralSelection.Kind,
        name: String,
        summary: String
    ) {
        switch query {
        case .type(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: kind,
                name: name,
                summary: summary
            )

        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: .declaration,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosingScope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func recordAnyDeclaration(
        _ node: some SyntaxProtocol,
        kind: StructuralSelection.Kind,
        name: String,
        summary: String
    ) {
        switch query {
        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: kind,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosingScope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func recordMemberLike(
        _ node: some SyntaxProtocol,
        name: String,
        summary: String
    ) {
        switch query {
        case .member(
            let requestedName,
            let parentType
        ):
            guard name == requestedName else {
                return
            }

            if let parentType {
                guard currentTypeName == parentType else {
                    return
                }
            }

            record(
                node,
                kind: .member,
                name: name,
                summary: summary
            )

        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: currentTypeName == nil ? .declaration : .member,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosingScope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func record(
        _ node: some SyntaxProtocol,
        kind: StructuralSelection.Kind,
        name: String?,
        summary: String
    ) {
        let startOffset = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let endOffset = node.endPositionBeforeTrailingTrivia.utf8Offset
        guard let lineRange = mapper.lineRange(
            startUTF8Offset: startOffset,
            endUTF8Offset: endOffset
        ) else {
            assertionFailure(
                "Failed to construct LineRange for Swift structural selection."
            )
            return
        }

        if case .enclosingScope(let location) = query {
            guard location.line > 0 else {
                return
            }

            if let column = location.column,
               column <= 0 {
                return
            }
        }

        collected.append(
            .init(
                selection: .init(
                    path: path,
                    lineRange: lineRange,
                    kind: kind,
                    symbolName: name,
                    summary: summary
                ),
                startUTF8Offset: startOffset,
                endUTF8Offset: endOffset
            )
        )
    }

    func variableName(
        from node: VariableDeclSyntax
    ) -> String {
        if let firstBinding = node.bindings.first {
            return normalized(
                firstBinding.pattern.description
            )
        }

        return "var"
    }

    func normalized(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func isNarrower(
        lhs: StructuralMatch,
        rhs: StructuralMatch
    ) -> Bool {
        let lhsWidth = lhs.endUTF8Offset - lhs.startUTF8Offset
        let rhsWidth = rhs.endUTF8Offset - rhs.startUTF8Offset

        if lhsWidth == rhsWidth {
            return lhs.selection.lineRange.start < rhs.selection.lineRange.start
        }

        return lhsWidth < rhsWidth
    }
}
