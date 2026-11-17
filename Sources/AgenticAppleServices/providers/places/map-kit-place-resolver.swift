import AgenticScheduling
import CoreLocation
import Foundation
import MapKit

/// Resolves location text, such as a client's address in a calendar event,
/// through Apple's geocoder. Results are cached on disk so an address is
/// looked up once; text that finds nothing is remembered for the process
/// only, so a corrected address resolves on the next run.
public actor MapKitPlaceResolver: PlaceResolver {
    private let cacheFile: URL?
    private var cache: [String: SchedulingPlace]?
    private var misses: Set<String> = []

    public init(cacheFile: URL? = nil) {
        self.cacheFile = cacheFile
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
        guard let coordinate = try await Self.geocode(text) else {
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

    @MainActor
    private static func geocode(_ text: String) async throws -> CLLocationCoordinate2D? {
        do {
            if #available(macOS 26.0, *) {
                guard let request = MKGeocodingRequest(addressString: text) else {
                    return nil
                }
                return try await request.mapItems.first?.location.coordinate
            }
            return try await CLGeocoder().geocodeAddressString(text).first?.location?.coordinate
        } catch let error as CLError where error.code == .geocodeFoundNoResult || error.code == .geocodeFoundPartialResult {
            return nil
        } catch let error as MKError where error.code == .placemarkNotFound {
            return nil
        }
    }

    private func loadedCache() -> [String: SchedulingPlace] {
        if let cache {
            return cache
        }
        var loaded: [String: SchedulingPlace] = [:]
        if let cacheFile,
           let data = try? Data(contentsOf: cacheFile),
           let decoded = try? JSONDecoder().decode([String: SchedulingPlace].self, from: data)
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
        guard let data = try? encoder.encode(cache) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheFile, options: .atomic)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
