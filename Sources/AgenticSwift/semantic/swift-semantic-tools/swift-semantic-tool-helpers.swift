import Agentic
import SwiftSemantics

func boundedLocations(
    values: [SwiftSemanticLocation],
    limit requestedLimit: Int?
) -> [SwiftSemanticLocation] {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )

    return Array(
        values.prefix(
            limit
        )
    )
}

func boundedTypeHierarchy(
    values: [SwiftSemanticTypeHierarchyItem],
    limit requestedLimit: Int?
) -> [SwiftSemanticTypeHierarchyItem] {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )

    return Array(
        values.prefix(
            limit
        )
    )
}
