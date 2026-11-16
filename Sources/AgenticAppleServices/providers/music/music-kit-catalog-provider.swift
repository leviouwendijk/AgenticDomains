import Foundation
import MusicKit

/// Catalog playback uses ApplicationMusicPlayer, NOT macOS Music.app.
/// Requires a bundled, MusicKit-entitled and audio-capable host.
@MainActor
public final class MusicKitCatalogProvider {
    public static let shared = MusicKitCatalogProvider()
    private var candidates: [String: Song] = [:]

    private init() {}

    public func authorizationStatus() -> MusicCatalogAuthorizationStatus {
        switch MusicAuthorization.currentStatus {
        case .notDetermined: return .not_determined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .authorized
        @unknown default: return .unknown
        }
    }

    public func authorize() async throws -> MusicCatalogAuthorizationStatus {
        try ensureHostConfigured()
        _ = await MusicAuthorization.request()
        return authorizationStatus()
    }

    public func search(_ query: MusicSearchQuery) async throws -> [MusicCatalogCandidate] {
        try ensureHostConfigured()
        guard authorizationStatus() == .authorized else {
            throw MusicCatalogServiceError.authorizationRequired
        }
        let term = query.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw AppleMusicServiceError.emptyQuery }
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = min(max(query.limit, 1), 30)
        let response = try await request.response()
        candidates = Dictionary(uniqueKeysWithValues: response.songs.map { ($0.id.rawValue, $0) })
        return response.songs.map { song in
            .init(
                identifier: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                album: song.albumTitle
            )
        }
    }

    public func play(_ identifier: String) async throws -> MusicCatalogPlayReceipt {
        guard #available(macOS 14.0, *) else {
            throw MusicCatalogServiceError.requiresMacOS14
        }

        try ensureHostConfigured()
        guard authorizationStatus() == .authorized else {
            throw MusicCatalogServiceError.authorizationRequired
        }
        guard let song = candidates[identifier] else {
            throw MusicCatalogServiceError.candidateUnavailable
        }
        let player = ApplicationMusicPlayer.shared
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.play()
        return .init(identifier: identifier, player: "application_music_player")
    }

    private func ensureHostConfigured() throws {
        guard let description = Bundle.main.object(
            forInfoDictionaryKey: "NSAppleMusicUsageDescription"
        ) as? String, !description.isEmpty else {
            throw AppleMusicServiceError.missingUsageDescription
        }
    }
}
