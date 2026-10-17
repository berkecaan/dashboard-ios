@preconcurrency import MapKit
import CoreLocation
import SwiftUI

@MainActor
final class NavigationViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var isBusy = false
    @Published private(set) var destination: MKMapItem?
    @Published private(set) var routes: [MKRoute] = []
    @Published var selectedRouteIndex = 0
    @Published private(set) var isNavigating = false
    @Published private(set) var stepIndex = 0
    @Published private(set) var remainingDistance: CLLocationDistance = 0
    @Published private(set) var distanceToManeuver: CLLocationDistance = 0
    @Published var errorMessage: String?

    var voiceEnabled = true

    private let speaker = Speaker()
    private var lastReroute = Date.distantPast
    private var spokenStep = -1
    private var nearSpokenStep = -1

    var selectedRoute: MKRoute? {
        routes.indices.contains(selectedRouteIndex) ? routes[selectedRouteIndex] : nil
    }

    var nextInstruction: String {
        guard let r = selectedRoute, !r.steps.isEmpty else { return "" }
        let i = min(stepIndex + 1, r.steps.count - 1)
        let t = r.steps[i].instructions
        return t.isEmpty ? "Rotayı takip edin" : t
    }

    /// Navigasyon sırasında kalan mesafeye göre, aksi halde seçili rotanın değerleri.
    var shownDistance: CLLocationDistance {
        isNavigating && remainingDistance > 0 ? remainingDistance : (selectedRoute?.distance ?? 0)
    }

    var shownTime: TimeInterval {
        guard let r = selectedRoute else { return 0 }
        guard isNavigating, remainingDistance > 0, r.distance > 0 else { return r.expectedTravelTime }
        return r.expectedTravelTime * min(1, remainingDistance / r.distance)
    }

    var eta: Date { Date().addingTimeInterval(shownTime) }

    // MARK: Arama ve rota

    func search(near loc: CLLocation?) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        isBusy = true
        defer { isBusy = false }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        if let loc {
            req.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        }
        do {
            let resp = try await MKLocalSearch(request: req).start()
            results = resp.mapItems
            if results.isEmpty { errorMessage = "Sonuç bulunamadı" }
        } catch {
            errorMessage = "Arama başarısız: \(error.localizedDescription)"
        }
    }

    func choose(_ item: MKMapItem) async {
        destination = item
        results = []
        query = item.name ?? ""
        await calculateRoutes()
    }

    func calculateRoutes() async {
        guard let destination else { return }
        isBusy = true
        defer { isBusy = false }
        let req = MKDirections.Request()
        req.source = MKMapItem.forCurrentLocation()
        req.destination = destination
        req.transportType = .automobile
        req.requestsAlternateRoutes = true
        do {
            let resp = try await MKDirections(request: req).calculate()
            routes = resp.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
            selectedRouteIndex = 0
            stepIndex = 0
            spokenStep = -1
            nearSpokenStep = -1
            if routes.isEmpty { errorMessage = "Rota bulunamadı" }
        } catch {
            routes = []
            errorMessage = "Rota hesaplanamadı: \(error.localizedDescription)"
        }
    }

    func clearDestination() {
        stop()
        destination = nil
        routes = []
        results = []
        query = ""
    }

    // MARK: Yönlendirme

    func start(from user: CLLocation?) {
        guard selectedRoute != nil else { return }
        isNavigating = true
        stepIndex = 0
        spokenStep = -1
        nearSpokenStep = -1
        updateProgress(user: user)
    }

    func stop() {
        isNavigating = false
        speaker.stop()
    }

    func updateProgress(user: CLLocation?) {
        guard isNavigating, let route = selectedRoute, let user else { return }
        let steps = route.steps
        guard !steps.isEmpty else { return }
        let here = MKMapPoint(user.coordinate)

        var idx = stepIndex
        while idx < steps.count - 1, Self.distance(from: here, toEndOf: steps[idx].polyline) < 30 { idx += 1 }
        if idx != stepIndex { stepIndex = idx }

        distanceToManeuver = Self.distance(from: here, toEndOf: steps[idx].polyline)
        remainingDistance = distanceToManeuver + steps[(idx + 1)...].reduce(0) { $0 + $1.distance }

        if idx >= steps.count - 1, distanceToManeuver < 40 {
            say("Hedefe ulaştınız")
            stop()
            return
        }

        if spokenStep != idx {
            spokenStep = idx
            say(nextInstruction)
        } else if nearSpokenStep != idx, distanceToManeuver < 150, idx < steps.count - 1 {
            nearSpokenStep = idx
            say("\(Int(distanceToManeuver / 10) * 10) metre sonra, \(nextInstruction)")
        }

        // Rotadan sapma: yeniden hesapla
        if Self.distanceToRoute(here, route.polyline) > 120,
           Date().timeIntervalSince(lastReroute) > 20 {
            lastReroute = Date()
            say("Rota yeniden hesaplanıyor")
            Task { await calculateRoutes() }
        }
    }

    private func say(_ text: String) {
        guard voiceEnabled, !text.isEmpty else { return }
        speaker.say(text)
    }

    // MARK: Geometri

    private static func distance(from p: MKMapPoint, toEndOf line: MKPolyline) -> CLLocationDistance {
        guard line.pointCount > 0 else { return .infinity }
        return MKMetersBetweenMapPoints(p, line.points()[line.pointCount - 1])
    }

    private static func distanceToRoute(_ p: MKMapPoint, _ line: MKPolyline) -> CLLocationDistance {
        let n = line.pointCount
        guard n >= 2 else { return .infinity }
        let pts = line.points()
        var best = Double.infinity
        for i in 0..<(n - 1) {
            let a = pts[i], b = pts[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let len2 = dx * dx + dy * dy
            var t = len2 > 0 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 : 0
            t = max(0, min(1, t))
            let px = a.x + t * dx, py = a.y + t * dy
            best = min(best, hypot(p.x - px, p.y - py))
        }
        return best * MKMetersPerMapPointAtLatitude(p.coordinate.latitude)
    }
}

extension MKMapRect {
    func padded(_ factor: Double) -> MKMapRect {
        insetBy(dx: -size.width * factor, dy: -size.height * factor)
    }
}
