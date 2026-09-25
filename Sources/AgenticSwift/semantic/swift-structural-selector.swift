import Foundation
import SwiftSemantics

public struct SwiftStructuralSelector:
    Sendable
{
    private let inspector: SwiftSemanticStructureInspector

    public init(
        inspector: SwiftSemanticStructureInspector = .init()
    ) {
        self.inspector = inspector
    }

    public func selections(
        in file: URL,
        query: SwiftSemanticStructureQuery
    ) throws -> [SwiftSemanticStructureSelection] {
        try inspector.selections(
            in: file,
            query: query
        )
    }
}
