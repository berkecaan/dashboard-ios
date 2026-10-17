import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var weather: WeatherViewModel
    @EnvironmentObject private var spotify: SpotifyService
    @EnvironmentObject private var nav: NavigationViewModel
    @EnvironmentObject private var network: NetworkMonitor
    @State private var night = false

    private var accent: Color { night ? Theme.amber : Theme.cyan }

    var body: some View {
        ZStack {
            background
            GeometryReader { geo in
                HStack(spacing: 14) {
                    NavigationPanel()
                        .frame(width: geo.size.width * 0.6)
                    rightColumn
                }
                .padding(14)
            }
            if !network.isOnline { offlineBanner }
            if night { Color.black.opacity(0.22).ignoresSafeArea().allowsHitTesting(false) }
        }
        .environment(\.dashAccent, accent)
        .tint(accent)
        .onAppear {
            location.start()
            spotify.clientID = settings.spotifyClientID
            nav.voiceEnabled = settings.voiceGuidance
        }
        .onChange(of: settings.spotifyClientID) { _, v in spotify.clientID = v }
        .onChange(of: settings.voiceGuidance) { _, v in nav.voiceEnabled = v }
        .onChange(of: location.location) { _, new in
            nav.updateProgress(user: new)
            Task { await weather.refreshIfNeeded(for: new) }
        }
        .onChange(of: network.isOnline) { _, online in
            if online { Task { await weather.refreshIfNeeded(for: location.location, force: true) } }
        }
        .task {
            while !Task.isCancelled {
                night = settings.isNight(sunrise: weather.sunrise, sunset: weather.sunset)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    @ViewBuilder
    private var rightColumn: some View {
        VStack(spacing: 14) {
            if settings.simpleMode {
                SimpleModePanel()
            } else {
                if settings.showSpotify { SpotifyPanel() }
                if settings.showWeather { WeatherVehiclePanel() }
                if !settings.showSpotify && !settings.showWeather { SimpleModePanel() }
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.02), Color(white: 0.10), Color(white: 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.14), .clear], center: .topTrailing,
                           startRadius: 20, endRadius: 520)
        }
        .ignoresSafeArea()
    }

    private var offlineBanner: some View {
        VStack {
            Label("İnternet yok — harita, hava durumu ve Spotify sınırlı çalışır", systemImage: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .glassEffect(.regular.tint(Color.red.opacity(0.35)), in: Capsule())
            Spacer()
        }
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
