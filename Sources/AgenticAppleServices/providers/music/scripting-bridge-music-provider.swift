import AppleMusicBridge
import Foundation
import iTunesLibrary

/// Local Music.app playback uses ScriptingBridge.
/// Search uses Apple's read-only local-library framework, not the global catalog.
public actor ScriptingBridgeMusicProvider: AppleMusicProvider {
    private let bridge: AppleMusicBridge

    public init() {
        self.bridge = AppleMusicBridge()
    }

    public func search(_ request: MusicSearchQuery) async throws -> [MusicCandidate] {
        let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw AppleMusicServiceError.emptyQuery
        }
        guard let description = Bundle.main.object(
            forInfoDictionaryKey: "NSAppleMusicUsageDescription"
        ) as? String, !description.isEmpty else {
            throw AppleMusicServiceError.missingUsageDescription
        }

        let library = try ITLibrary(apiVersion: "1.0")
        let limit = min(max(request.limit, 1), 30)
        let matches = library.allMediaItems.compactMap { item -> MusicCandidate? in
            let title = item.title
            let artist = item.artist?.name ?? ""
            let album: String? = item.album.title
            guard title.localizedCaseInsensitiveContains(query)
                || artist.localizedCaseInsensitiveContains(query)
                || (album?.localizedCaseInsensitiveContains(query) ?? false)
            else {
                return nil
            }
            let identifier = String(format: "%016llX", item.persistentID.uint64Value)
            return .init(identifier: identifier, title: title, artist: artist, album: album)
        }
        return Array(matches.sorted { lhs, rhs in
            let left = lhs.title.localizedLowercase.hasPrefix(query.localizedLowercase)
            let right = rhs.title.localizedLowercase.hasPrefix(query.localizedLowercase)
            if left != right { return left }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            if lhs.artist != rhs.artist { return lhs.artist < rhs.artist }
            return lhs.identifier < rhs.identifier
        }.prefix(limit))
    }

    public func play(_ identifier: String) async throws -> MusicPlaybackSnapshot {
        guard identifier.range(
            of: "^[0-9A-Fa-f]{16}$",
            options: .regularExpression
        ) != nil else {
            throw AppleMusicServiceError.invalidPersistentID
        }
        try bridge.playPersistentID(identifier)
        return try await nowPlaying()
    }

    public func control(_ action: MusicControlAction) async throws -> MusicPlaybackSnapshot {
        try bridge.control(action.rawValue)
        return try await nowPlaying()
    }

    public func setVolume(_ value: Int) async throws -> MusicPlaybackSnapshot {
        guard (0...100).contains(value) else {
            throw AppleMusicServiceError.invalidVolume
        }
        try bridge.setVolume(value)
        return try await nowPlaying()
    }

    public func nowPlaying() async throws -> MusicPlaybackSnapshot {
        let value = try bridge.snapshot()
        let track: MusicCandidate?
        if let identifier = value.persistentID, let title = value.title {
            track = .init(
                identifier: identifier,
                title: title,
                artist: value.artist ?? "",
                album: value.album
            )
        } else {
            track = nil
        }
        return .init(
            state: value.state,
            track: track,
            positionSeconds: value.position,
            volume: value.volume
        )
    }
}
