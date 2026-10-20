import SwiftUI

struct WeatherVehiclePanel: View {
    @EnvironmentObject private var weather: WeatherViewModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dashAccent) private var accent

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 240
            VStack(alignment: .leading, spacing: compact ? 6 : 16) {
                HStack(spacing: 6) {
                    Label(location.city, systemImage: "location.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: compact ? 22 : 42, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: weather.symbol).symbolRenderingMode(.multicolor)
                        .font(.system(size: compact ? 23 : 40))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weather.temperature.map { "\(Int($0.rounded()))°" } ?? "--°")
                            .font(.system(size: compact ? 32 : 64, weight: .bold, design: .rounded))
                        Text(weather.errorText ?? weather.conditionText)
                            .font(.system(size: compact ? 10 : 14)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(Int(location.speedKmh.rounded()))")
                                .font(.system(size: compact ? 32 : 64, weight: .heavy, design: .rounded))
                                .monospacedDigit().foregroundStyle(accent)
                            Text("km/sa").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                        }
                        if settings.showTrip {
                            Text(String(format: "%.1f km yol", location.tripDistanceKm))
                                .font(.system(size: compact ? 10 : 14)).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                if settings.showForecast && !weather.daily.isEmpty && geo.size.height > 135 {
                    HStack(spacing: 6) {
                        ForEach(weather.daily.dropFirst().prefix(3)) { day in
                            VStack(spacing: 2) {
                                Text(day.date, format: .dateTime.weekday(.abbreviated))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 3) {
                                    Image(systemName: day.symbol).symbolRenderingMode(.multicolor)
                                    Text("\(Int(day.high.rounded()))°/\(Int(day.low.rounded()))°")
                                }
                            }
                            .font(.system(size: compact ? 9 : 14))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                HStack {
                    Link("Hava verisi: Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { Task { await weather.refreshIfNeeded(for: location.location, force: true) } } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11)).padding(4)
                    }.buttonStyle(.plain).accessibilityLabel("Hava durumunu yenile")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .padding(12)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(.white.opacity(0.10)))
    }
}

struct SimpleModePanel: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dashAccent) private var accent

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("\(Int(location.speedKmh.rounded()))")
                    .font(.system(size: min(110, geo.size.height * 0.3), weight: .heavy, design: .rounded))
                    .monospacedDigit().foregroundStyle(accent)
                Text("km/sa").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(String(format: "%.1f km yol", location.tripDistanceKm)).font(.caption).foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                Spacer(minLength: 0)
                if spotify.status == .connected {
                    Text(spotify.track?.title ?? "Spotify'da bir şarkı başlatın")
                        .font(.caption).lineLimit(1)
                    HStack(spacing: 12) {
                        GlassIconButton(systemName: "backward.fill", size: 40) { spotify.previous() }
                        GlassIconButton(systemName: spotify.isPlaying ? "pause.fill" : "play.fill", size: 44, tint: accent) { spotify.togglePlayPause() }
                        GlassIconButton(systemName: "forward.fill", size: 40) { spotify.next() }
                    }
                }
            }.frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(12)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(.white.opacity(0.10)))
    }
}
