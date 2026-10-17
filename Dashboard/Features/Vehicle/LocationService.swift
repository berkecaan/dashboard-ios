@preconcurrency import CoreLocation
import SwiftUI

@MainActor
final class LocationService: ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var speedKmh: Double = 0
    @Published private(set) var tripDistanceKm: Double = 0
    @Published private(set) var isDenied = false
    @Published private(set) var city = "—"

    private let manager = CLLocationManager()
    private var session: CLServiceSession?
    private var task: Task<Void, Never>?
    private var lastCounted: CLLocation?
    private var lastGeocoded: CLLocation?

    func start() {
        guard task == nil else { return }
        manager.requestWhenInUseAuthorization()
        session = CLServiceSession(authorization: .whenInUse)
        task = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    guard let self else { return }
                    self.handle(update)
                }
            } catch {
                self?.isDenied = true
            }
        }
    }

    func resetTrip() {
        tripDistanceKm = 0
        lastCounted = location
    }

    private func handle(_ update: CLLocationUpdate) {
        isDenied = update.authorizationDenied || manager.authorizationStatus == .denied
        guard let loc = update.location else { return }
        location = loc

        let kmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
        speedKmh = kmh < 2 ? 0 : kmh

        if loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 30 {
            if let last = lastCounted {
                let d = loc.distance(from: last)
                if d > 5 { tripDistanceKm += d / 1000; lastCounted = loc }
            } else {
                lastCounted = loc
            }
        }

        if lastGeocoded == nil || loc.distance(from: lastGeocoded!) > 5000 {
            lastGeocoded = loc
            Task { [weak self] in
                let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
                if let p = marks?.first {
                    self?.city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? "—"
                }
            }
        }
    }
}
