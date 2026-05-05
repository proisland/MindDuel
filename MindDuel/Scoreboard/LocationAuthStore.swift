import CoreLocation
import Combine

/// Observable wrapper around `CLLocationManager` authorization status so SwiftUI
/// views can react to permission changes (#77). Also owns the first
/// `requestWhenInUseAuthorization()` call — without it iOS never shows the
/// native prompt, so "Posisjon" never appears under the app's iOS settings page
/// and the "Åpne innstillinger"-knappen ender opp på en side uten valget.
@MainActor
final class LocationAuthStore: NSObject, ObservableObject {
    static let shared = LocationAuthStore()

    @Published private(set) var status: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool {
        status == .authorizedAlways || status == .authorizedWhenInUse
    }

    /// Triggers iOS' native permission prompt the first time. After the user
    /// responds (allow/deny), iOS adds MindDuel to Innstillinger → Personvern →
    /// Posisjonstjenester, so a later "Åpne innstillinger" takes them somewhere
    /// useful.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
}

extension LocationAuthStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let new = manager.authorizationStatus
        Task { @MainActor in self.status = new }
    }
}
