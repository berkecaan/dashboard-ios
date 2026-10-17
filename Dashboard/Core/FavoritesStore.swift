@preconcurrency import MapKit
import SwiftUI

struct FavoritePlace: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [FavoritePlace] = []
    @Published private(set) var parked: FavoritePlace?

    private let d = UserDefaults.standard

    init() {
        if let data = d.data(forKey: "favorites"),
           let list = try? JSONDecoder().decode([FavoritePlace].self, from: data) { favorites = list }
        if let data = d.data(forKey: "parked"),
           let p = try? JSONDecoder().decode(FavoritePlace.self, from: data) { parked = p }
    }

    func isFavorite(_ item: MKMapItem?) -> Bool {
        guard let item else { return false }
        let c = item.placemark.coordinate
        return favorites.contains { abs($0.latitude - c.latitude) < 0.0005 && abs($0.longitude - c.longitude) < 0.0005 }
    }

    func toggle(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        if isFavorite(item) {
            favorites.removeAll { abs($0.latitude - c.latitude) < 0.0005 && abs($0.longitude - c.longitude) < 0.0005 }
        } else {
            favorites.append(FavoritePlace(name: item.name ?? "Favori", latitude: c.latitude, longitude: c.longitude))
        }
        saveFavorites()
    }

    func remove(_ place: FavoritePlace) {
        favorites.removeAll { $0.id == place.id }
        saveFavorites()
    }

    @discardableResult
    func saveParked(at location: CLLocation?) -> Bool {
        guard let location else { return false }
        let p = FavoritePlace(name: "Park konumu", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        parked = p
        if let data = try? JSONEncoder().encode(p) { d.set(data, forKey: "parked") }
        return true
    }

    func clearParked() {
        parked = nil
        d.removeObject(forKey: "parked")
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) { d.set(data, forKey: "favorites") }
    }
}
