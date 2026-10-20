@preconcurrency import MapKit
import SwiftUI
import UIKit

struct NavigationPanel: View {
    @EnvironmentObject private var nav: NavigationViewModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.dashAccent) private var accent

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var camera: MapCamera?
    @State private var showFavorites = false
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            map
            VStack(spacing: 10) {
                if nav.isNavigating {
                    instructionBanner
                } else {
                    searchBar
                    if !nav.results.isEmpty { resultsList }
                    if showFavorites { favoritesList }
                }
                Spacer(minLength: 0)
                if nav.destination != nil, !nav.routes.isEmpty { routeCard }
            }
            .padding(14)
            sideControls
            if location.isDenied { permissionOverlay }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("Navigasyon", isPresented: Binding(
            get: { nav.errorMessage != nil },
            set: { if !$0 { nav.errorMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: { Text(nav.errorMessage ?? "") }
    }

    // MARK: Harita

    private var routeOrder: [Int] {
        // Seçili rota en üstte çizilsin
        nav.routes.indices.sorted { a, _ in a != nav.selectedRouteIndex }
    }

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            if let dest = nav.destination {
                Marker(dest.name ?? "Hedef", coordinate: dest.placemark.coordinate).tint(.red)
            }
            ForEach(routeOrder, id: \.self) { i in
                MapPolyline(nav.routes[i].polyline)
                    .stroke(i == nav.selectedRouteIndex ? accent : Color.gray.opacity(0.6),
                            lineWidth: i == nav.selectedRouteIndex ? 9 : 5)
            }
            if let p = favorites.parked {
                Marker("Park", systemImage: "parkingsign.circle.fill", coordinate: p.coordinate).tint(.blue)
            }
        }
        .mapStyle(.standard(elevation: .realistic, showsTraffic: true))
        .mapControls { MapCompass(); MapScaleView() }
        .onMapCameraChange(frequency: .onEnd) { ctx in camera = ctx.camera }
    }

    // MARK: Üst alan

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Hedef ara", text: $nav.query)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { Task { await nav.search(near: location.location) } }
                .font(.title3)
            if nav.isBusy { ProgressView() }
            if !nav.query.isEmpty {
                Button {
                    nav.clearDestination()
                    fitUser()
                } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).frame(height: 56)
        .padding(.trailing, 54)
        .glassEffect(.regular, in: Capsule())
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(nav.results.prefix(8).enumerated()), id: \.offset) { _, item in
                    Button {
                        searchFocused = false
                        Task { await nav.choose(item); fitRoute() }
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Konum").font(.headline)
                                Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10).padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.3)
                }
            }
        }
        .frame(maxHeight: 190)
        .padding(.trailing, 54)
        .glassPanel(cornerRadius: 24)
    }

    private var favoritesList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let p = favorites.parked {
                    favoriteRow(icon: "parkingsign.circle.fill", title: "Park konumuna git", place: p, parked: true)
                }
                ForEach(favorites.favorites) { place in
                    favoriteRow(icon: "star.fill", title: place.name, place: place, parked: false)
                }
                if favorites.favorites.isEmpty && favorites.parked == nil {
                    Text("Henüz favori yok. Bir hedef seçip yıldıza dokunun.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(16)
                }
            }
        }
        .frame(maxHeight: 190)
        .padding(.trailing, 54)
        .glassPanel(cornerRadius: 24)
    }

    private func favoriteRow(icon: String, title: String, place: FavoritePlace, parked: Bool) -> some View {
        HStack {
            Button {
                showFavorites = false
                Task { await nav.choose(place.mapItem); fitRoute() }
            } label: {
                HStack {
                    Image(systemName: icon).font(.title2).foregroundStyle(parked ? .blue : .yellow)
                    Text(title).font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                if parked { favorites.clearParked() } else { favorites.remove(place) }
            } label: { Image(systemName: "trash").foregroundStyle(.secondary).frame(width: 44, height: 44) }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }

    private var instructionBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 38, weight: .bold)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.distance(nav.distanceToManeuver)).font(.system(size: 30, weight: .bold, design: .rounded))
                Text(nav.nextInstruction).font(.headline).lineLimit(2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .padding(.trailing, 54)
        .glassPanel(cornerRadius: 28)
    }

    // MARK: Alt rota kartı

    private var routeCard: some View {
        VStack(spacing: 8) {
            if nav.routes.count > 1 && !nav.isNavigating {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(nav.routes.indices, id: \.self) { index in
                            Button {
                                nav.selectedRouteIndex = index
                                fitRoute()
                            } label: {
                                Text("Rota \(index + 1) · \(Fmt.duration(nav.routes[index].expectedTravelTime))")
                                    .font(.caption.weight(.semibold)).padding(10)
                                    .background(index == nav.selectedRouteIndex ? accent.opacity(0.3) : .white.opacity(0.08), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nav.eta, format: .dateTime.hour().minute())
                        .font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("Varış").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.duration(nav.shownTime)).font(.subheadline.weight(.semibold))
                    Text(Fmt.distance(nav.shownDistance)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !nav.isNavigating, let destination = nav.destination {
                    GlassIconButton(systemName: favorites.isFavorite(destination) ? "star.fill" : "star",
                                    size: 36, tint: .yellow) { favorites.toggle(destination) }
                }
                Button {
                    if nav.isNavigating { nav.stop(); fitRoute() }
                    else {
                        nav.start(from: location.location)
                        position = .userLocation(followsHeading: true, fallback: .automatic)
                    }
                } label: {
                    Text(nav.isNavigating ? "Bitir" : "Başlat")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.black)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(nav.isNavigating ? Color.red : accent, in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 22)
        .padding(.trailing, 54)
    }

    // MARK: Yan kontroller

    private var sideControls: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                GlassIconButton(systemName: "gearshape.fill", size: 40) { showSettings = true }
                GlassIconButton(systemName: "star.circle", size: 40) { showFavorites.toggle() }
                GlassIconButton(systemName: "parkingsign", size: 40) { favorites.saveParked(at: location.location) }
                Spacer(minLength: 0)
                GlassIconButton(systemName: "plus", size: 40) { zoom(0.55) }
                GlassIconButton(systemName: "minus", size: 40) { zoom(1.8) }
                GlassIconButton(systemName: "location.fill", size: 40, tint: accent) { fitUser() }
            }
            .padding(10)
        }
    }

    private var permissionOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill").font(.largeTitle)
            Text("Konum izni gerekli").font(.title3.bold())
            Text("Harita, rota ve hız için Ayarlar'dan konum iznini açın.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Ayarları Aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.glassProminent)
        }
        .padding(28)
        .glassPanel(cornerRadius: 28)
    }

    // MARK: Kamera

    private func zoom(_ factor: Double) {
        guard let c = camera else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            position = .camera(MapCamera(centerCoordinate: c.centerCoordinate,
                                         distance: max(150, c.distance * factor),
                                         heading: c.heading, pitch: c.pitch))
        }
    }

    private func fitUser() {
        withAnimation { position = .userLocation(followsHeading: nav.isNavigating, fallback: .automatic) }
    }

    private func fitRoute() {
        if let r = nav.selectedRoute {
            withAnimation { position = .rect(r.polyline.boundingMapRect.padded(0.35)) }
        }
    }
}
