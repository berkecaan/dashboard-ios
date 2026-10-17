import SwiftUI

struct SpotifyPanel: View {
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dashAccent) private var accent

    var body: some View {
        Group {
            switch spotify.status {
            case .notConfigured: message("Spotify için Ayarlar'dan Client ID girin", icon: "gearshape")
            case .disconnected: connectView
            case .connecting: message("Spotify'a bağlanılıyor…", icon: "arrow.triangle.2.circlepath")
            case .connected: playerView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .glassPanel()
    }

    private func message(_ text: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(accent)
            Text(text).font(.headline).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }

    private var connectView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note").font(.system(size: 40)).foregroundStyle(.green)
            Text("Spotify bağlı değil").font(.headline)
            Button("Spotify'a Bağlan") { Task { await spotify.connect() } }
                .buttonStyle(.glassProminent).tint(.green).controlSize(.large)
            if let n = spotify.notice { Text(n).font(.caption).foregroundStyle(.orange) }
        }
    }

    private var playerView: some View {
        HStack(spacing: 16) {
            artwork
            VStack(alignment: .leading, spacing: 6) {
                statusRow
                Text(spotify.track?.title ?? "Çalan şarkı yok")
                    .font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(spotify.track?.artist ?? (spotify.notice ?? "Spotify'da bir şarkı başlatın"))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 0)
                progress
                controls
            }
        }
    }

    private var artwork: some View {
        Group {
            if let url = spotify.track?.artworkURL {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.white.opacity(0.08) }
            } else {
                ZStack { Color.white.opacity(0.08); Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary) }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: spotify.isPlaying ? 22 : 8, y: 10)
        .scaleEffect(spotify.isPlaying ? 1 : 0.93)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: spotify.isPlaying)
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform").symbolEffect(.variableColor.iterative, isActive: spotify.isPlaying)
                .foregroundStyle(.green)
            Text(spotify.deviceName.map { "Spotify · \($0)" } ?? "Spotify bağlı")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Button { spotify.signOut() } label: {
                Image(systemName: "link.badge.plus").rotationEffect(.degrees(45)).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
    }

    private var progress: some View {
        let dur = max(1, spotify.track?.durationMs ?? 1)
        let frac = Double(spotify.progressMs) / Double(dur)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(accent).frame(width: geo.size.width * min(1, max(0, frac)))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                    spotify.seek(toFraction: v.location.x / geo.size.width)
                })
            }
            .frame(height: 8)
            HStack {
                Text(time(spotify.progressMs)); Spacer(); Text(time(spotify.track?.durationMs ?? 0))
            }
            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            Spacer()
            GlassIconButton(systemName: "backward.fill", size: 52) { spotify.previous() }
            GlassIconButton(systemName: spotify.isPlaying ? "pause.fill" : "play.fill", size: 62, tint: accent) {
                spotify.togglePlayPause()
            }
            GlassIconButton(systemName: "forward.fill", size: 52) { spotify.next() }
            Spacer()
        }
    }

    private func time(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
