import SwiftUI

struct WeatherVehiclePanel: View {
    @EnvironmentObject private var weather: WeatherViewModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dashAccent) private var accent

    var body: some View {
        VStack(spacing: 8) {
            topRow
            Divider().opacity(0.25)
            bottomRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .glassPanel()
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Label(location.city, systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(weather.temperature.map { "\(Int($0.rounded()))°" } ?? "--°")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    Image(systemName: weather.symbol).symbolRenderingMode(.multicolor).font(.system(size: 30))
                }
                if let err = weather.errorText {
                    Text(err).font(.caption).foregroundStyle(.orange)
                } else {
                    Text(conditionLine).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ctx.date, format: .dateTime.hour().minute())
                        .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(ctx.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var conditionLine: String {
        var s = weather.conditionText
        if let f = weather.feelsLike { s += " · Hissedilen \(Int(f.rounded()))°" }
        return s
    }

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(location.speedKmh.rounded()))")
                        .font(.system(size: 46, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.25), value: Int(location.speedKmh.rounded()))
                    Text("km/s").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                if settings.showTrip {
                    Button { location.resetTrip() } label: {
                        Label(String(format: "%.1f km", location.tripDistanceKm), systemImage: "road.lanes")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            if settings.showForecast {
                HStack(spacing: 12) {
                    ForEach(weather.daily.dropFirst().prefix(3)) { d in
                        VStack(spacing: 2) {
                            Text(d.date, format: .dateTime.weekday(.abbreviated)).font(.caption2).foregroundStyle(.secondary)
                            Image(systemName: d.symbol).symbolRenderingMode(.multicolor).font(.callout)
                            Text("\(Int(d.high.rounded()))°/\(Int(d.low.rounded()))°").font(.caption2.weight(.semibold))
                        }
                    }
                }
            }
        }
    }
}

/// Sade mod: büyük hız + saat + mini müzik kontrolü
struct SimpleModePanel: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dashAccent) private var accent

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Text("\(Int(location.speedKmh.rounded()))")
                .font(.system(size: 110, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(accent)
            Text("km/s").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(ctx.date, format: .dateTime.hour().minute())
                    .font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            Spacer(minLength: 0)
            if spotify.status == .connected {
                HStack(spacing: 18) {
                    Text(spotify.track?.title ?? "—").font(.subheadline).lineLimit(1).frame(maxWidth: 140, alignment: .leading)
                    GlassIconButton(systemName: "backward.fill", size: 50) { spotify.previous() }
                    GlassIconButton(systemName: spotify.isPlaying ? "pause.fill" : "play.fill", size: 58, tint: accent) { spotify.togglePlayPause() }
                    GlassIconButton(systemName: "forward.fill", size: 50) { spotify.next() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .glassPanel()
    }
}
