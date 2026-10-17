import WeatherKit
@preconcurrency import CoreLocation
import SwiftUI

struct DayForecast: Identifiable {
    let id: Date
    let date: Date
    let high: Double
    let low: Double
    let symbol: String
}

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var temperature: Double?
    @Published private(set) var feelsLike: Double?
    @Published private(set) var conditionText = "—"
    @Published private(set) var symbol = "cloud"
    @Published private(set) var daily: [DayForecast] = []
    @Published private(set) var sunrise: Date?
    @Published private(set) var sunset: Date?
    @Published private(set) var errorText: String?

    private var lastFetch: Date?
    private var lastLocation: CLLocation?
    private var loading = false

    func refreshIfNeeded(for loc: CLLocation?, force: Bool = false) async {
        guard let loc, !loading else { return }
        if !force, let lf = lastFetch, let ll = lastLocation,
           Date().timeIntervalSince(lf) < 900, loc.distance(from: ll) < 5000 { return }
        loading = true
        defer { loading = false }
        do {
            let (current, forecast) = try await WeatherService.shared.weather(for: loc, including: .current, .daily)
            temperature = current.temperature.converted(to: .celsius).value
            feelsLike = current.apparentTemperature.converted(to: .celsius).value
            conditionText = current.condition.description
            symbol = current.symbolName
            let days = forecast.forecast
            daily = days.prefix(4).map {
                DayForecast(id: $0.date, date: $0.date,
                            high: $0.highTemperature.converted(to: .celsius).value,
                            low: $0.lowTemperature.converted(to: .celsius).value,
                            symbol: $0.symbolName)
            }
            sunrise = days.first?.sun.sunrise
            sunset = days.first?.sun.sunset
            errorText = nil
            lastFetch = Date()
        } catch {
            errorText = "Hava durumu alınamadı"
            lastFetch = Date().addingTimeInterval(-840) // ~60 sn sonra tekrar dene
        }
        lastLocation = loc
    }
}
