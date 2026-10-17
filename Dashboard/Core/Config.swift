import Foundation

enum Config {
    static let spotifyRedirectScheme = "dashboard-spotify"
    static let spotifyRedirectURI = "dashboard-spotify://callback"
    static let spotifyScopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

    /// Build ayarı SPOTIFY_CLIENT_ID ile Info.plist'e gömülen değer (boş olabilir).
    static var bundledSpotifyClientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
