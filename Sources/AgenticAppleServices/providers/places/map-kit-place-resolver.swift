import AgenticScheduling
import Apple
import Foundation
import Readers
import Writers

/// Resolves location text, such as a client's address in a calendar event,
/// through Apple's geocoder. Results are cached on disk so an address is
/// looked up once; text that finds nothing is remembered for the process
/// only, so a corrected address resolves on the next run.
public actor MapKitPlaceResolver: PlaceResolver {
    private let cacheFile: URL?
    private let geocoder: MapKitGeocoder
    private var cache: [String: SchedulingPlace]?
    private var misses: Set<String> = []

    public init(
        cacheFile: URL? = nil,
        geocoder: MapKitGeocoder = .init()
    ) {
        self.cacheFile = cacheFile
        self.geocoder = geocoder
    }

    public func resolve(_ text: String) async throws -> SchedulingPlace? {
        let key = Self.normalized(text)
        guard !key.isEmpty else {
            return nil
        }
        if let known = loadedCache()[key] {
            return known
        }
        if misses.contains(key) {
            return nil
        }
        guard let coordinate = try await geocoder.coordinate(of: text) else {
            misses.insert(key)
            return nil
        }
        let place = SchedulingPlace(
            label: text.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        cache?[key] = place
        persist()
        return place
    }

    private func loadedCache() -> [String: SchedulingPlace] {
        if let cache {
            return cache
        }
        var loaded: [String: SchedulingPlace] = [:]
        if let cacheFile,
           let read = try? TextFileReader(cacheFile).read(options: .init(missingFilePolicy: .returnEmpty)),
           read.existed,
           let decoded = try? JSONDecoder().decode([String: SchedulingPlace].self, from: Data(read.text.utf8))
        {
            loaded = decoded
        }
        cache = loaded
        return loaded
    }

    /// Best effort: a cache that cannot be written only costs lookups.
    private func persist() {
        guard let cacheFile, let cache else {
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(cache),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        _ = try? FileWriter(cacheFile).write(text, options: .overwriteWithoutBackup)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
