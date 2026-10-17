import SwiftUI
import UIKit

@main
struct DashboardApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var location = LocationService()
    @StateObject private var nav = NavigationViewModel()
    @StateObject private var spotify = SpotifyService()
    @StateObject private var weather = WeatherViewModel()
    @StateObject private var network = NetworkMonitor()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(settings)
                .environmentObject(favorites)
                .environmentObject(location)
                .environmentObject(nav)
                .environmentObject(spotify)
                .environmentObject(weather)
                .environmentObject(network)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onChange(of: scenePhase) { _, phase in
                    spotify.setActive(phase == .active)
                    UIApplication.shared.isIdleTimerDisabled = (phase == .active)
                }
        }
    }
}
