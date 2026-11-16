import Foundation
import Macros
import Schema

@JSONSchema
public struct MusicSearchQuery: Codable, Sendable, Hashable {
    public let query: String
    public let limit: Int

    public init(query: String, limit: Int = 10) {
        self.query = query
        self.limit = limit
    }
}

@JSONSchema
public struct MusicCandidate: Codable, Sendable, Hashable {
    public let identifier: String
    public let title: String
    public let artist: String
    public let album: String?

    public init(identifier: String, title: String, artist: String, album: String?) {
        self.identifier = identifier
        self.title = title
        self.artist = artist
        self.album = album
    }
}

@JSONSchema
public enum MusicControlAction: String, Codable, Sendable, Hashable {
    case play
    case pause
    case stop
    case next
    case previous
}

@JSONSchema
public struct MusicPlaybackSnapshot: Codable, Sendable, Hashable {
    public let state: String
    public let track: MusicCandidate?
    public let positionSeconds: Double
    public let volume: Int

    public init(state: String, track: MusicCandidate?, positionSeconds: Double, volume: Int) {
        self.state = state
        self.track = track
        self.positionSeconds = positionSeconds
        self.volume = volume
    }
}

public enum AppleMusicServiceError: Error, Sendable, LocalizedError {
    case emptyQuery
    case missingUsageDescription
    case invalidPersistentID
    case invalidVolume

    public var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Music search requires nonempty text."
        case .missingUsageDescription:
            return "The executing app must provide NSAppleMusicUsageDescription to access the music library."
        case .invalidPersistentID:
            return "Expected a 16-digit hexadecimal Music.app persistent ID."
        case .invalidVolume:
            return "Music volume must be between 0 and 100."
        }
    }
}

@JSONSchema
public enum MusicCatalogAuthorizationStatus: String, Codable, Sendable, Hashable {
    case not_determined
    case denied
    case restricted
    case authorized
    case unknown
}

@JSONSchema
public struct MusicCatalogCandidate: Codable, Sendable, Hashable {
    public let identifier: String
    public let title: String
    public let artist: String
    public let album: String?

    public init(identifier: String, title: String, artist: String, album: String?) {
        self.identifier = identifier
        self.title = title
        self.artist = artist
        self.album = album
    }
}

@JSONSchema
public struct MusicCatalogPlayReceipt: Codable, Sendable, Hashable {
    public let identifier: String
    public let player: String

    public init(identifier: String, player: String) {
        self.identifier = identifier
        self.player = player
    }
}

public enum MusicCatalogServiceError: Error, Sendable, LocalizedError {
    case authorizationRequired
    case candidateUnavailable
    case requiresMacOS14

    public var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            return "MusicKit authorization required. Use music_catalog_authorize in a properly bundled MusicKit-enabled host."
        case .candidateUnavailable:
            return "Catalog candidate is no longer cached. Search again and choose an exact returned identifier."
        case .requiresMacOS14:
            return "Apple Music catalog playback requires macOS 14 or newer."
        }
    }
}
