import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var spotify: SpotifyService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Görünüm") {
                    Toggle("Sade sürüş modu", isOn: $settings.simpleMode)
                    Toggle("Otomatik gece modu", isOn: $settings.autoNight)
                    Toggle("Spotify paneli", isOn: $settings.showSpotify)
                    Toggle("Hava durumu paneli", isOn: $settings.showWeather)
                    Toggle("Günlük tahmin", isOn: $settings.showForecast)
                    Toggle("Gidilen mesafe", isOn: $settings.showTrip)
                }
                Section {
                    Link("Open-Meteo hava verileri", destination: URL(string: "https://open-meteo.com/")!)
                    Text("Hava tahmini için konum koordinatlarınız Open-Meteo'ya gönderilir. Apple WeatherKit yetkisi veya API anahtarı gerekmez.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text("Hava durumu")
                }
                Section("Navigasyon") {
                    Toggle("Sesli yönlendirme (Türkçe)", isOn: $settings.voiceGuidance)
                    Button("Gidilen mesafeyi sıfırla") { location.resetTrip() }
                    if favorites.parked != nil {
                        Button("Park konumunu sil", role: .destructive) { favorites.clearParked() }
                    }
                }
                Section {
                    TextField("Spotify Client ID", text: $settings.spotifyClientID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if spotify.status == .connected {
                        Button("Spotify bağlantısını kaldır", role: .destructive) { spotify.signOut() }
                    } else {
                        Button("Spotify'a bağlan") { Task { await spotify.connect() } }
                            .disabled(settings.spotifyClientID.isEmpty)
                    }
                } header: {
                    Text("Spotify")
                } footer: {
                    Text("Redirect URI: \(Config.spotifyRedirectURI). Oynatma kontrolü Spotify Premium ve aktif bir cihaz gerektirir.")
                }
            }
            .navigationTitle("Ayarlar")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } } }
        }
    }
}
