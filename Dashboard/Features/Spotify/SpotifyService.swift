import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Security
import UIKit

struct SpotifyTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

struct SpotifyTrack: Equatable {
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let durationMs: Int
}

enum SpotifyError: Error { case unauthorized, authFailed, cancelled }

// MARK: - PKCE

enum PKCE {
    static func verifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension JSONDecoder {
    static var snake: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}

// MARK: - Web auth

@MainActor
final class WebAuthRunner: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func run(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: url, callback: .customScheme(scheme)) { callback, error in
                if let callback { cont.resume(returning: callback) }
                else { cont.resume(throwing: error ?? SpotifyError.cancelled) }
            }
            s.presentationContextProvider = self
            self.session = s
            s.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

// MARK: - API modelleri

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
}

private struct PlaybackState: Decodable {
    struct Artist: Decodable { let name: String }
    struct Img: Decodable { let url: String; let width: Int? }
    struct Album: Decodable { let name: String; let images: [Img] }
    struct Item: Decodable {
        let name: String
        let durationMs: Int
        let artists: [Artist]?
        let album: Album?
        let images: [Img]?
    }
    struct Device: Decodable { let name: String }
    let isPlaying: Bool
    let progressMs: Int?
    let item: Item?
    let device: Device?
}

// MARK: - Servis

@MainActor
final class SpotifyService: ObservableObject {
    enum Status: Equatable { case notConfigured, disconnected, connecting, connected }

    @Published private(set) var status: Status = .notConfigured
    @Published private(set) var track: SpotifyTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var progressMs = 0
    @Published private(set) var deviceName: String?
    @Published var notice: String?

    var clientID = "" { didSet { refreshStatus() } }

    private var tokens: SpotifyTokens?
    private var pollTask: Task<Void, Never>?
    private var active = true
    private let auth = WebAuthRunner()
    private let keychainKey = "spotify.tokens"

    init() {
        if let data = Keychain.get(keychainKey),
           let t = try? JSONDecoder().decode(SpotifyTokens.self, from: data) { tokens = t }
    }

    // MARK: Durum

    private func refreshStatus() {
        if status == .connecting { return }
        if clientID.isEmpty { status = .notConfigured; stopPolling(); return }
        status = tokens == nil ? .disconnected : .connected
        if status == .connected { startPolling() } else { stopPolling() }
    }

    func setActive(_ value: Bool) {
        active = value
        if value, status == .connected { Task { await fetchState() } }
    }

    // MARK: Bağlan / çıkış

    func connect() async {
        guard !clientID.isEmpty else { status = .notConfigured; return }
        status = .connecting
        notice = nil
        let verifier = PKCE.verifier()
        let state = PKCE.verifier()
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "scope", value: Config.spotifyScopes),
            .init(name: "redirect_uri", value: Config.spotifyRedirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            .init(name: "state", value: state)
        ]
        do {
            let callback = try await auth.run(url: comps.url!, scheme: Config.spotifyRedirectScheme)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value else { throw SpotifyError.authFailed }
            let r = try await tokenRequest([
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": Config.spotifyRedirectURI,
                "client_id": clientID,
                "code_verifier": verifier
            ])
            store(access: r.accessToken, refresh: r.refreshToken ?? "", expiresIn: r.expiresIn)
            status = .connected
            startPolling()
        } catch {
            status = clientID.isEmpty ? .notConfigured : .disconnected
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                notice = "Spotify bağlantısı kurulamadı"
            }
        }
    }

    func signOut() {
        tokens = nil
        Keychain.remove(keychainKey)
        track = nil
        isPlaying = false
        deviceName = nil
        stopPolling()
        status = clientID.isEmpty ? .notConfigured : .disconnected
    }

    // MARK: Oynatma kontrolü (Premium + aktif cihaz gerekir)

    func togglePlayPause() {
        let wasPlaying = isPlaying
        isPlaying.toggle()
        Task { await command("PUT", wasPlaying ? "/me/player/pause" : "/me/player/play") }
    }
    func next() { Task { await command("POST", "/me/player/next") } }
    func previous() { Task { await command("POST", "/me/player/previous") } }

    func seek(toFraction f: Double) {
        guard let t = track else { return }
        let ms = Int(Double(t.durationMs) * min(max(f, 0), 1))
        progressMs = ms
        Task { await command("PUT", "/me/player/seek", query: [.init(name: "position_ms", value: "\(ms)")]) }
    }

    private func command(_ method: String, _ path: String, query: [URLQueryItem] = []) async {
        do {
            let (_, code) = try await send(method, path, query: query)
            switch code {
            case 200, 202, 204: notice = nil
            case 403: notice = "Oynatma kontrolü Spotify Premium gerektirir"
            case 404: notice = "Aktif Spotify cihazı yok. Spotify uygulamasında bir şarkı başlatın."
            default: notice = "Spotify komutu başarısız (\(code))"
            }
            try? await Task.sleep(for: .milliseconds(500))
            await fetchState()
        } catch {
            notice = "Spotify'a ulaşılamıyor"
        }
    }

    // MARK: Durum sorgulama

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                if self.active {
                    if tick % 3 == 0 {
                        await self.fetchState()
                    } else if self.isPlaying, let t = self.track {
                        self.progressMs = min(self.progressMs + 1000, t.durationMs)
                    }
                    tick += 1
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func fetchState() async {
        guard status == .connected else { return }
        do {
            let (data, code) = try await send("GET", "/me/player")
            switch code {
            case 200:
                let s = try JSONDecoder.snake.decode(PlaybackState.self, from: data)
                apply(s)
                notice = nil
            case 204:
                track = nil
                isPlaying = false
                deviceName = nil
                notice = "Aktif Spotify cihazı yok. Spotify uygulamasında bir şarkı başlatın."
            default:
                break
            }
        } catch SpotifyError.unauthorized {
            signOut()
            notice = "Spotify oturumu sona erdi, tekrar bağlanın"
        } catch SpotifyError.authFailed {
            signOut()
            notice = "Spotify oturumu yenilenemedi, tekrar bağlanın"
        } catch {
            notice = "Spotify'a ulaşılamıyor"
        }
    }

    private func apply(_ s: PlaybackState) {
        isPlaying = s.isPlaying
        progressMs = s.progressMs ?? 0
        deviceName = s.device?.name
        guard let it = s.item else { track = nil; return }
        let img = it.album?.images.first ?? it.images?.first
        track = SpotifyTrack(
            title: it.name,
            artist: it.artists?.map(\.name).joined(separator: ", ") ?? "Podcast",
            album: it.album?.name ?? "",
            artworkURL: img.flatMap { URL(string: $0.url) },
            durationMs: it.durationMs)
    }

    // MARK: HTTP ve token

    private func send(_ method: String, _ path: String, query: [URLQueryItem] = [],
                      retry: Bool = true) async throws -> (Data, Int) {
        let token = try await validToken()
        var comps = URLComponents(string: "https://api.spotify.com/v1\(path)")!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 {
            guard retry else { throw SpotifyError.unauthorized }
            try await refresh()
            return try await send(method, path, query: query, retry: false)
        }
        return (data, code)
    }

    private func validToken() async throws -> String {
        guard let t = tokens else { throw SpotifyError.unauthorized }
        if t.expiresAt.timeIntervalSinceNow < 60 { try await refresh() }
        guard let fresh = tokens else { throw SpotifyError.unauthorized }
        return fresh.accessToken
    }

    private func refresh() async throws {
        guard let t = tokens, !t.refreshToken.isEmpty else { throw SpotifyError.unauthorized }
        let r = try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": t.refreshToken,
            "client_id": clientID
        ])
        store(access: r.accessToken, refresh: r.refreshToken ?? t.refreshToken, expiresIn: r.expiresIn)
    }

    private func store(access: String, refresh: String, expiresIn: Int) {
        let t = SpotifyTokens(accessToken: access, refreshToken: refresh,
                              expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)))
        tokens = t
        if let data = try? JSONEncoder().encode(t) { Keychain.set(data, for: keychainKey) }
    }

    private func tokenRequest(_ params: [String: String]) async throws -> TokenResponse {
        var c = URLComponents()
        c.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = c.percentEncodedQuery?.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw SpotifyError.authFailed }
        return try JSONDecoder.snake.decode(TokenResponse.self, from: data)
    }
}
