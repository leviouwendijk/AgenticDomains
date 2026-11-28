import Agentic
import Apple
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("music_search")
    struct SearchMusic {
        public typealias Input = MusicSearchQuery
        public typealias Output = [MusicCandidate]
        public static let purpose = "Search the authorized Music.app library for track candidates; not the entire Apple Music catalog. Returns exact persistent IDs."
        public static let risk: ActionRisk = .observe
        private let provider: any AppleMusicProvider
        public init(provider: any AppleMusicProvider = ScriptingBridgeMusicProvider()) {
            self.provider = provider
        }
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await provider.search(input)
        }
    }

    @Tool("music_play")
    struct PlayMusic {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            public let identifier: String
            public init(identifier: String) { self.identifier = identifier }
        }
        public typealias Output = MusicPlaybackSnapshot
        public static let purpose = "Play an exact library persistent ID selected from apple_tool_music_search in macOS Music.app. Never pick a fuzzy candidate automatically."
        public static let risk: ActionRisk = .boundedmutate
        private let provider: any AppleMusicProvider
        public init(provider: any AppleMusicProvider = ScriptingBridgeMusicProvider()) {
            self.provider = provider
        }
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await provider.play(input.identifier)
        }
    }

    @Tool("music_now_playing")
    struct MusicNowPlaying {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable { public init() {} }
        public typealias Output = MusicPlaybackSnapshot
        public static let purpose = "Read macOS Music.app playback state, track, position, and volume."
        public static let risk: ActionRisk = .observe
        private let provider: any AppleMusicProvider
        public init(provider: any AppleMusicProvider = ScriptingBridgeMusicProvider()) {
            self.provider = provider
        }
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            _ = input
            return try await provider.nowPlaying()
        }
    }

    @Tool("music_control")
    struct ControlMusic {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            public let action: MusicControlAction
            public init(action: MusicControlAction) { self.action = action }
        }
        public typealias Output = MusicPlaybackSnapshot
        public static let purpose = "Control macOS Music.app with play, pause, stop, next, or previous."
        public static let risk: ActionRisk = .boundedmutate
        private let provider: any AppleMusicProvider
        public init(provider: any AppleMusicProvider = ScriptingBridgeMusicProvider()) {
            self.provider = provider
        }
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await provider.control(input.action)
        }
    }

    @Tool("music_set_volume")
    struct SetMusicVolume {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            public let volume: Int
            public init(volume: Int) { self.volume = volume }
        }
        public typealias Output = MusicPlaybackSnapshot
        public static let purpose = "Set Music.app volume to an exact integer in 0...100."
        public static let risk: ActionRisk = .boundedmutate
        private let provider: any AppleMusicProvider
        public init(provider: any AppleMusicProvider = ScriptingBridgeMusicProvider()) {
            self.provider = provider
        }
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await provider.setVolume(input.volume)
        }
    }

    @Tool("music_catalog_authorization_status")
    struct MusicCatalogStatus {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable { public init() {} }
        public typealias Output = MusicCatalogAuthorizationStatus
        public static let purpose = "Observe MusicKit authorization for the app-owned Apple Music catalog player. No prompt."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            _ = input
            return await MusicKitCatalogProvider.shared.authorizationStatus()
        }
    }

    @Tool("music_catalog_authorize")
    struct AuthorizeMusicCatalog {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable { public init() {} }
        public typealias Output = MusicCatalogAuthorizationStatus
        public static let purpose = "Request MusicKit consent in a properly bundled MusicKit-enabled host; may show a system permission prompt."
        public static let risk: ActionRisk = .boundedmutate
        public init() {}
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            _ = input
            return try await MusicKitCatalogProvider.shared.authorize()
        }
    }

    @Tool("music_catalog_search")
    struct SearchMusicCatalog {
        public typealias Input = MusicSearchQuery
        public typealias Output = [MusicCatalogCandidate]
        public static let purpose = "Search the entire Apple Music song catalog using MusicKit. Return exact song IDs; do not change playback."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await MusicKitCatalogProvider.shared.search(input)
        }
    }

    @Tool("music_catalog_play")
    struct PlayMusicCatalog {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            public let identifier: String
            public init(identifier: String) { self.identifier = identifier }
        }
        public typealias Output = MusicCatalogPlayReceipt
        public static let purpose = "Play an exact song from apple_tool_music_catalog_search through MusicKit ApplicationMusicPlayer. Playback belongs to the host app, not Music.app."
        public static let risk: ActionRisk = .boundedmutate
        public init() {}
        public func call(_ input: Input, in _: CapabilityContext) async throws -> Output {
            try await MusicKitCatalogProvider.shared.play(input.identifier)
        }
    }
}
