import SwiftUI

struct SpotifyPanel: View {
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dashAccent) private var accent
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geo in
            Group {
                switch spotify.status {
                case .notConfigured: message("Ayarlar'dan Spotify Client ID girin", icon: "gearshape")
                case .disconnected: connectView
                case .connecting: message("Spotify'a bağlanılıyor…", icon: "arrow.triangle.2.circlepath")
                case .connected:
                    if spotify.track == nil { emptyPlayer }
                    else { player(width: geo.size.width, height: geo.size.height) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(12)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(.white.opacity(0.10)))
        .task { await spotify.fetchState() }
    }

    private func message(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.green)
            Text(text).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding(8)
    }

    private var connectView: some View {
        VStack(spacing: 8) {
            Label("Spotify", systemImage: "music.note").font(.headline).foregroundStyle(.green)
            Button("Spotify'a Bağlan") { Task { await spotify.connect() } }
                .buttonStyle(.borderedProminent).tint(.green)
            if let notice = spotify.notice { Text(notice).font(.caption).lineLimit(2).foregroundStyle(.secondary) }
        }
    }

    private var emptyPlayer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Spotify bağlı", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.green)
            Text("Müziğini başlat").font(.headline)
            Text(spotify.notice ?? "Spotify'da bir şarkı aç, ardından Dashboard'a dön.")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 10) {
                Button("Spotify'ı aç", systemImage: "arrow.up.right.square") {
                    openURL(URL(string: "https://open.spotify.com/")!)
                }.buttonStyle(.borderedProminent).tint(.green).font(.caption.weight(.semibold))
                Button { Task { await spotify.fetchState() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 40, height: 40)
                }.buttonStyle(.plain).accessibilityLabel("Spotify durumunu yenile")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func player(width: CGFloat, height: CGFloat) -> some View {
        let compact = height < 230
        let artSize = min(width * 0.26, height * 0.65, compact ? 88 : 220)
        return HStack(spacing: 10) {
            artwork.frame(width: artSize, height: artSize).clipped()
            VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                Label(spotify.deviceName.map { "Spotify · \($0)" } ?? "Spotify", systemImage: "waveform")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.green).lineLimit(1)
                Text(spotify.track?.title ?? "")
                    .font(compact ? .subheadline.weight(.bold) : .title2.weight(.bold))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(spotify.notice ?? spotify.track?.artist ?? "")
                    .font(.caption).foregroundStyle(spotify.notice == nil ? Color.secondary : Color.orange).lineLimit(1)
                Spacer(minLength: 0)
                progress
                HStack(spacing: compact ? 8 : 18) {
                    Spacer(minLength: 0)
                    GlassIconButton(systemName: "backward.fill", size: compact ? 38 : 52) { spotify.previous() }
                    GlassIconButton(systemName: spotify.isPlaying ? "pause.fill" : "play.fill", size: compact ? 42 : 62, tint: accent) {
                        spotify.togglePlayPause()
                    }
                    GlassIconButton(systemName: "forward.fill", size: compact ? 38 : 52) { spotify.next() }
                    Spacer(minLength: 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var artwork: some View {
        Group {
            if let url = spotify.track?.artworkURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                    placeholder: { Color.white.opacity(0.08) }
            } else {
                ZStack { Color.white.opacity(0.08); Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.green) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var progress: some View {
        let duration = max(1, spotify.track?.durationMs ?? 1)
        let fraction = min(1, max(0, Double(spotify.progressMs) / Double(duration)))
        return VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(accent).frame(width: geo.size.width * fraction)
                }
                .frame(height: 4).frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    guard geo.size.width > 0 else { return }
                    spotify.seek(toFraction: value.location.x / geo.size.width)
                })
            }.frame(height: 12)
            HStack { Text(time(spotify.progressMs)); Spacer(); Text(time(spotify.track?.durationMs ?? 0)) }
                .font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func time(_ ms: Int) -> String {
        let seconds = max(0, ms / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
