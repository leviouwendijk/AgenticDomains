public protocol AppleMusicProvider: Sendable {
    func search(_ request: MusicSearchQuery) async throws -> [MusicCandidate]
    func play(_ identifier: String) async throws -> MusicPlaybackSnapshot
    func control(_ action: MusicControlAction) async throws -> MusicPlaybackSnapshot
    func setVolume(_ value: Int) async throws -> MusicPlaybackSnapshot
    func nowPlaying() async throws -> MusicPlaybackSnapshot
}
