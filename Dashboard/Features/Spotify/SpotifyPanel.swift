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
        .clipShape(RoundedRectangle(cornerRadius: 25))
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

    @ViewBuilder
    private func player(width: CGFloat, height: CGFloat) -> some View {
        if width >= 440 && height >= 290 {
            expandedPlayer(width: width, height: height)
        } else {
            compactPlayer(width: width, height: height)
        }
    }

    private func expandedPlayer(width: CGFloat, height: CGFloat) -> some View {
        let tight = height < 350 || width < 600
        let inset: CGFloat = tight ? 12 : 20
        let groupWidth = min(max(0, width - inset * 2), 940)
        let gap: CGFloat = tight ? 24 : 34
        let coverSize = min(height - inset * 2, groupWidth * 0.40, 340)
        let detailWidth = max(0, groupWidth - coverSize - gap)
        return ZStack {
            if let url = spotify.track?.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .frame(width: width, height: height)
                .blur(radius: 55)
                .opacity(0.16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.42)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
            HStack(alignment: .center, spacing: gap) {
                artwork
                    .frame(width: coverSize, height: coverSize)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                VStack(alignment: .leading, spacing: tight ? 10 : 14) {
                    HStack(spacing: 7) {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative, isActive: spotify.isPlaying)
                            .foregroundStyle(.green)
                        Text(spotify.track == nil ? "SPOTIFY" : (spotify.isPlaying ? "ŞİMDİ ÇALIYOR" : "DURAKLATILDI"))
                            .tracking(1.4)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(spotify.track?.title ?? "Müziğin burada")
                            .font(.system(size: tight ? 26 : 32, weight: .bold, design: .rounded))
                            .lineLimit(tight ? 1 : 2).minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                        Text(spotify.track?.artist ?? "Oynat veya bir cihaz seç")
                            .font(.system(size: tight ? 15 : 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }
                    progress(compact: false).disabled(spotify.track == nil)
                    playbackControls(compact: false, tight: tight)
                        .frame(maxWidth: .infinity)
                    HStack {
                        deviceSelector(compact: false)
                        Spacer(minLength: 0)
                        if spotify.isSendingCommand { ProgressView().controlSize(.small) }
                    }
                    if let notice = spotify.notice {
                        Text(notice).font(.caption).foregroundStyle(.orange).lineLimit(2)
                    }
                }
                .frame(width: detailWidth, alignment: .leading)
            }
            .frame(width: groupWidth, height: max(0, height - inset * 2))
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func compactPlayer(width: CGFloat, height: CGFloat) -> some View {
        let coverSize = min(width * 0.26, height * 0.65, 88)
        return HStack(spacing: 10) {
            artwork.frame(width: coverSize, height: coverSize).clipped()
            VStack(alignment: .leading, spacing: 4) {
                deviceSelector(compact: true)
                Text(spotify.track?.title ?? "Müziğin burada")
                    .font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
                Text(spotify.notice ?? spotify.track?.artist ?? "Oynat veya bir cihaz seç")
                    .font(.caption)
                    .foregroundStyle(spotify.notice == nil ? Color.secondary : Color.orange)
                    .lineLimit(1)
                Spacer(minLength: 0)
                progress(compact: true).disabled(spotify.track == nil)
                playbackControls(compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func deviceSelector(compact: Bool) -> some View {
        Button {
            spotify.needsDeviceSelection = true
        } label: {
            HStack(spacing: 5) {
                Label(spotify.deviceName.map { "Spotify · \($0)" } ?? "Spotify · Cihaz seç",
                      systemImage: "speaker.wave.2.fill")
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: compact ? 10 : 11, weight: .semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, compact ? 0 : 10)
            .frame(minHeight: compact ? 20 : 32, alignment: .leading)
            .background(compact ? Color.clear : Color.green.opacity(0.09), in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Spotify cihazlarını seç")
    }

    private func playbackControls(compact: Bool, tight: Bool = false) -> some View {
        let side: CGFloat = compact ? 38 : (tight ? 48 : 56)
        let main: CGFloat = compact ? 42 : (tight ? 66 : 78)
        return HStack(spacing: compact ? 8 : (tight ? 18 : 24)) {
            Spacer(minLength: 0)
            GlassIconButton(systemName: "backward.fill", size: side) { spotify.previous() }
                .disabled(spotify.track == nil)
                .accessibilityLabel("Önceki parça")
            Button { spotify.togglePlayPause() } label: {
                Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: main * 0.36, weight: .bold))
                    .foregroundStyle(compact ? accent : Color.black)
                    .frame(width: main, height: main)
                    .background(compact ? Color.white.opacity(0.06) : accent, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spotify.isPlaying ? "Duraklat" : "Oynat")
            GlassIconButton(systemName: "forward.fill", size: side) { spotify.next() }
                .disabled(spotify.track == nil)
                .accessibilityLabel("Sonraki parça")
            Spacer(minLength: 0)
        }
        .disabled(spotify.isSendingCommand)
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

    private func progress(compact: Bool) -> some View {
        let duration = max(1, spotify.track?.durationMs ?? 1)
        let fraction = min(1, max(0, Double(spotify.progressMs) / Double(duration)))
        return VStack(spacing: compact ? 2 : 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(accent).frame(width: geo.size.width * fraction)
                }
                .frame(height: compact ? 4 : 5).frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    guard geo.size.width > 0 else { return }
                    spotify.seek(toFraction: value.location.x / geo.size.width)
                })
            }.frame(height: compact ? 12 : 22)
            HStack { Text(time(spotify.progressMs)); Spacer(); Text(time(spotify.track?.durationMs ?? 0)) }
                .font(.system(size: compact ? 9 : 12, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
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
