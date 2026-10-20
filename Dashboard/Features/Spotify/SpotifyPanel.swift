import SwiftUI

struct SpotifyPanel: View {
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dashAccent) private var accent

    var body: some View {
        GeometryReader { geo in
            Group {
                switch spotify.status {
                case .notConfigured: message("Ayarlar'dan Spotify Client ID girin", icon: "gearshape")
                case .disconnected: connectView
                case .connecting: message("Spotify'a bağlanılıyor…", icon: "arrow.triangle.2.circlepath")
                case .connected: player(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(12)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(.white.opacity(0.10)))
        .sheet(isPresented: $spotify.needsDeviceSelection) { SpotifyDevicesView() }
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

    private func player(width: CGFloat, height: CGFloat) -> some View {
        let compact = height < 230
        let artSize = min(width * 0.26, height * 0.65, compact ? 88 : 220)
        return HStack(spacing: 10) {
            artwork.frame(width: artSize, height: artSize).clipped()
            VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                Button {
                    spotify.needsDeviceSelection = true
                } label: {
                    HStack(spacing: 4) {
                        Label(spotify.deviceName.map { "Spotify · \($0)" } ?? "Spotify · Cihaz seç", systemImage: "speaker.wave.2.fill")
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
                    .frame(minHeight: compact ? 20 : 32, alignment: .leading)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Spotify cihazlarını seç")
                Text(spotify.track?.title ?? "Müziğin burada")
                    .font(compact ? .subheadline.weight(.bold) : .title2.weight(.bold))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(spotify.notice ?? spotify.track?.artist ?? "Oynat veya bir cihaz seç")
                    .font(.caption).foregroundStyle(spotify.notice == nil ? Color.secondary : Color.orange).lineLimit(1)
                Spacer(minLength: 0)
                progress.disabled(spotify.track == nil)
                HStack(spacing: compact ? 8 : 18) {
                    Spacer(minLength: 0)
                    GlassIconButton(systemName: "backward.fill", size: compact ? 38 : 52) { spotify.previous() }
                        .disabled(spotify.track == nil)
                    GlassIconButton(systemName: spotify.isPlaying ? "pause.fill" : "play.fill", size: compact ? 42 : 62, tint: accent) {
                        spotify.togglePlayPause()
                    }
                    GlassIconButton(systemName: "forward.fill", size: compact ? 38 : 52) { spotify.next() }
                        .disabled(spotify.track == nil)
                    Spacer(minLength: 0)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .disabled(spotify.isSendingCommand)
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

/// Device selection remains inside Dashboard; playback controls never launch another app.
private struct SpotifyDevicesView: View {
    @EnvironmentObject private var spotify: SpotifyService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Cihazı seçtiğinizde müzik orada başlar. Kontroller Dashboard içinde kalır.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Spotify cihazları") {
                    if spotify.isLoadingDevices && spotify.devices.isEmpty {
                        ProgressView("Cihazlar aranıyor…")
                    } else if spotify.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Kullanılabilir cihaz yok", systemImage: "speaker.slash")
                                .font(.headline)
                            Text("Spotify'ın bu iPhone'da veya başka bir cihazda erişilebilir olması gerekir. Dashboard yeni bir Spotify ses cihazı oluşturamaz.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    } else {
                        ForEach(spotify.devices) { device in
                            Button {
                                Task {
                                    if await spotify.useDevice(device) { dismiss() }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: device.symbol).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(device.name)
                                        Text(device.isRestricted ? "Bu cihaz uzaktan kontrol edilemiyor" : (device.isActive ? "Şu anda aktif" : "Bu cihazda oynat"))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if device.id == spotify.deviceID { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                }
                                .contentShape(Rectangle()).padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(!device.canControl || spotify.isSendingCommand)
                        }
                    }
                    if let notice = spotify.deviceNotice {
                        Text(notice).font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    Button("Cihazları yenile", systemImage: "arrow.clockwise") {
                        Task { await spotify.refreshDevices(force: true) }
                    }.disabled(spotify.isLoadingDevices)
                } footer: {
                    Text("Spotify Premium gerekir. Hesaba bağlanmak tek başına bir oynatma cihazını etkinleştirmez.")
                }
            }
            .navigationTitle("Spotify cihazları")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
            .task { await spotify.refreshDevices(force: true) }
        }
    }
}
