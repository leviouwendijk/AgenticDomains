import Foundation

/// Resolves free-text locations to places. Unresolvable text returns `nil`;
/// a resolver never guesses.
public protocol PlaceResolver: Sendable {
    func resolve(_ text: String) async throws -> SchedulingPlace?
}

/// Resolves a fixed set of known places (office, studio, client sites) by
/// label or alias, ignoring case and surrounding whitespace.
public struct StaticPlaceResolver: PlaceResolver {
    private let places: [String: SchedulingPlace]

    /// - Parameter places: each place with the aliases that also name it.
    public init(_ places: [(place: SchedulingPlace, aliases: [String])] = []) {
        var table: [String: SchedulingPlace] = [:]
        for entry in places {
            for name in [entry.place.label] + entry.aliases {
                table[Self.normalized(name)] = entry.place
            }
        }
        self.places = table
    }

    public func resolve(_ text: String) async throws -> SchedulingPlace? {
        places[Self.normalized(text)]
    }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Tries resolvers in order; the first answer wins.
public struct ChainedPlaceResolver: PlaceResolver {
    private let resolvers: [any PlaceResolver]

    public init(_ resolvers: [any PlaceResolver]) {
        self.resolvers = resolvers
    }

    public func resolve(_ text: String) async throws -> SchedulingPlace? {
        for resolver in resolvers {
            if let place = try await resolver.resolve(text) {
                return place
            }
        }
        return nil
    }
}
