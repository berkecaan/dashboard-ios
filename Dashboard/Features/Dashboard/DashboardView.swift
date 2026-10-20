import SwiftUI

private enum DashboardScreen { case panel, apps, map, music, weather, trip }

struct DashboardView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var weather: WeatherViewModel
    @EnvironmentObject private var spotify: SpotifyService
    @EnvironmentObject private var nav: NavigationViewModel
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var night = false
    @State private var screen: DashboardScreen = .panel
    @State private var showSettings = false

    private var accent: Color { night ? Theme.amber : Theme.cyan }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.04, blue: 0.07), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            GeometryReader { geo in
                let gap: CGFloat = 10
                let dockWidth: CGFloat = 58
                let contentWidth = max(0, geo.size.width - dockWidth - gap)
                HStack(spacing: gap) {
                    dock.frame(width: dockWidth, height: geo.size.height)
                    content(width: contentWidth, height: geo.size.height)
                        .frame(width: contentWidth, height: geo.size.height)
                }
            }
            .padding(10)
            if !network.isOnline {
                VStack {
                    Label("İnternet bağlantısı yok", systemImage: "wifi.slash")
                        .font(.caption.weight(.semibold)).padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }.padding(.top, 8).allowsHitTesting(false)
            }
        }
        .environment(\.dashAccent, accent)
        .tint(accent)
        .sheet(isPresented: $showSettings) { SettingsView() }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await weather.refreshIfNeeded(for: location.location) }
            }
        }
        .task {
            while !Task.isCancelled {
                await weather.refreshIfNeeded(for: location.location)
                night = settings.isNight(sunrise: weather.sunrise, sunset: weather.sunset)
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    @ViewBuilder private func content(width: CGFloat, height: CGFloat) -> some View {
        switch screen {
        case .panel:
            if width < 600 {
                ScrollView {
                    VStack(spacing: 10) {
                        NavigationPanel().frame(height: max(320, height))
                        if settings.simpleMode { SimpleModePanel().frame(height: 350) }
                        else {
                            if settings.showSpotify { SpotifyPanel().frame(height: 200) }
                            if settings.showWeather { WeatherVehiclePanel().frame(height: 210) }
                        }
                    }.frame(width: width)
                }
            } else {
                let rightWidth = max(0, (width - 10) * 0.42)
                HStack(spacing: 10) {
                    NavigationPanel().frame(width: max(0, width - rightWidth - 10), height: height)
                    rightColumn(height: height).frame(width: rightWidth, height: height)
                }
            }
        case .apps: apps
        case .map: NavigationPanel()
        case .music: SpotifyPanel()
        case .weather: WeatherVehiclePanel()
        case .trip: SimpleModePanel()
        }
    }

    private func rightColumn(height: CGFloat) -> some View {
        let both = settings.showSpotify && settings.showWeather && !settings.simpleMode
        return VStack(spacing: 10) {
            if settings.simpleMode || (!settings.showSpotify && !settings.showWeather) {
                SimpleModePanel().frame(height: height)
            } else {
                if settings.showSpotify { SpotifyPanel().frame(height: both ? (height - 10) * 0.52 : height) }
                if settings.showWeather { WeatherVehiclePanel().frame(height: both ? (height - 10) * 0.48 : height) }
            }
        }
    }

    private var dock: some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
            }.padding(.top, 10)
            Spacer(minLength: 0)
            dockButton("Panel", icon: "rectangle.split.2x2.fill", target: .panel)
            dockButton("Harita", icon: "map.fill", target: .map)
            dockButton("Müzik", icon: "music.note", target: .music)
            dockButton("Uygulamalar", icon: "square.grid.2x2.fill", target: .apps)
            Spacer(minLength: 0)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 19))
                    .frame(width: 44, height: 44).foregroundStyle(.secondary)
            }.buttonStyle(.plain).accessibilityLabel("Ayarlar")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(0.08)))
    }

    private func dockButton(_ title: String, icon: String, target: DashboardScreen) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { screen = target } } label: {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(screen == target ? accent : .white.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(screen == target ? accent.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityLabel(title)
    }

    private var apps: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dashboard").font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Yolculuğun için her şey bir arada").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(location.city, systemImage: "location.fill")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    appTile("Panel", icon: "rectangle.split.2x2.fill", color: .orange, height: (geo.size.height - 78) / 2) { screen = .panel }
                    appTile("Harita", icon: "map.fill", color: .blue, height: (geo.size.height - 78) / 2) { screen = .map }
                    appTile("Spotify", icon: "music.note", color: .green, height: (geo.size.height - 78) / 2) { screen = .music }
                    appTile("Hava Durumu", icon: "cloud.sun.fill", color: .cyan, height: (geo.size.height - 78) / 2) { screen = .weather }
                    appTile("Yol Bilgisayarı", icon: "speedometer", color: .purple, height: (geo.size.height - 78) / 2) { screen = .trip }
                    appTile("Ayarlar", icon: "gearshape.fill", color: .gray, height: (geo.size.height - 78) / 2) { showSettings = true }
                }
            }.padding(.horizontal, 12)
        }
    }

    private func appTile(_ title: String, icon: String, color: Color, height: CGFloat,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: min(34, max(22, height * 0.26)), weight: .medium))
                    .frame(width: 58, height: 58)
                    .background(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 17))
                    .shadow(color: color.opacity(0.15), radius: 10, y: 5)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: max(90, height))
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).foregroundStyle(.white)
    }
}
