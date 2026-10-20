import Foundation
@preconcurrency import CoreLocation
import SwiftUI

struct DayForecast: Identifiable {
    let id: Date
    let date: Date
    let high: Double
    let low: Double
    let symbol: String
}

/// Open-Meteo public forecast endpoint. No Apple WeatherKit entitlement is required.
/// Coordinates are sent only to obtain weather for the user's location.
@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var temperature: Double?
    @Published private(set) var feelsLike: Double?
    @Published private(set) var conditionText = "Konum bekleniyor"
    @Published private(set) var symbol = "cloud"
    @Published private(set) var daily: [DayForecast] = []
    @Published private(set) var sunrise: Date?
    @Published private(set) var sunset: Date?
    @Published private(set) var errorText: String?

    private var lastFetch: Date?
    private var lastAttempt: Date?
    private var lastLocation: CLLocation?
    private var loading = false

    func refreshIfNeeded(for location: CLLocation?, force: Bool = false) async {
        guard let location, !loading else { return }
        if !force {
            if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
            if let lastFetch, let lastLocation,
               Date().timeIntervalSince(lastFetch) < 900,
               location.distance(from: lastLocation) < 5000 { return }
        }
        loading = true
        lastAttempt = Date()
        defer { loading = false }
        do {
            let request = try Self.request(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let forecast = try JSONDecoder().decode(OpenMeteoForecast.self, from: data)
            let today = forecast.current
            temperature = today.temperature_2m
            feelsLike = today.apparent_temperature
            let condition = Self.condition(code: today.weather_code, isDay: today.is_day == 1)
            conditionText = condition.text
            symbol = condition.symbol
            let days = forecast.daily
            let count = min(days.time.count, days.temperature_2m_max.count,
                            days.temperature_2m_min.count, days.weather_code.count)
            daily = (0..<count).map { index in
                let date = Date(timeIntervalSince1970: days.time[index])
                return DayForecast(id: date, date: date, high: days.temperature_2m_max[index],
                                   low: days.temperature_2m_min[index],
                                   symbol: Self.condition(code: days.weather_code[index], isDay: true).symbol)
            }
            sunrise = days.sunrise.first.flatMap { $0 }.map { Date(timeIntervalSince1970: $0) }
            sunset = days.sunset.first.flatMap { $0 }.map { Date(timeIntervalSince1970: $0) }
            errorText = nil
            lastFetch = Date()
            lastLocation = location
        } catch is CancellationError {
            return
        } catch {
            errorText = temperature == nil ? "Hava verisine ulaşılamıyor" : "Son alınan hava verisi"
        }
    }

    private static func request(latitude: Double, longitude: Double) throws -> URLRequest {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"),
            .init(name: "forecast_days", value: "4"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        return URLRequest(url: url, timeoutInterval: 15)
    }

    private static func condition(code: Int, isDay: Bool) -> (text: String, symbol: String) {
        switch code {
        case 0: return ("Açık", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2: return ("Parçalı bulutlu", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Bulutlu", "cloud.fill")
        case 45, 48: return ("Sisli", "cloud.fog.fill")
        case 51, 53, 55, 56, 57: return ("Çisenti", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("Yağmurlu", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86: return ("Karlı", "cloud.snow.fill")
        case 95, 96, 99: return ("Gök gürültülü", "cloud.bolt.rain.fill")
        default: return ("Hava durumu", "cloud")
        }
    }
}

private struct OpenMeteoForecast: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let is_day: Int
    }
    struct Daily: Decodable {
        let time: [TimeInterval]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weather_code: [Int]
        let sunrise: [TimeInterval?]
        let sunset: [TimeInterval?]
    }
    let current: Current
    let daily: Daily
}
