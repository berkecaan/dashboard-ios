import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var showSpotify: Bool { didSet { Self.d.set(showSpotify, forKey: "showSpotify") } }
    @Published var showWeather: Bool { didSet { Self.d.set(showWeather, forKey: "showWeather") } }
    @Published var showForecast: Bool { didSet { Self.d.set(showForecast, forKey: "showForecast") } }
    @Published var showTrip: Bool { didSet { Self.d.set(showTrip, forKey: "showTrip") } }
    @Published var simpleMode: Bool { didSet { Self.d.set(simpleMode, forKey: "simpleMode") } }
    @Published var autoNight: Bool { didSet { Self.d.set(autoNight, forKey: "autoNight") } }
    @Published var voiceGuidance: Bool { didSet { Self.d.set(voiceGuidance, forKey: "voiceGuidance") } }
    @Published var spotifyClientID: String { didSet { Self.d.set(spotifyClientID, forKey: "spotifyClientID") } }

    private static let d = UserDefaults.standard
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) as? Bool ?? fallback
    }

    init() {
        showSpotify = Self.bool("showSpotify", true)
        showWeather = Self.bool("showWeather", true)
        showForecast = Self.bool("showForecast", true)
        showTrip = Self.bool("showTrip", true)
        simpleMode = Self.bool("simpleMode", false)
        autoNight = Self.bool("autoNight", true)
        voiceGuidance = Self.bool("voiceGuidance", true)
        let stored = Self.d.string(forKey: "spotifyClientID") ?? ""
        spotifyClientID = stored.isEmpty ? Config.bundledSpotifyClientID : stored
    }

    /// Gün doğumu/batımı biliniyorsa onları, yoksa saate göre gece kararı.
    func isNight(now: Date = .now, sunrise: Date?, sunset: Date?) -> Bool {
        guard autoNight else { return false }
        if let sunrise, let sunset { return now < sunrise || now > sunset }
        let h = Calendar.current.component(.hour, from: now)
        return h >= 19 || h < 6
    }
}
