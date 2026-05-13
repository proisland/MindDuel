import Foundation
import UIKit

/// Batches telemetry events and flushes them to the backend.
/// Events are accumulated in memory; a flush is triggered automatically
/// after 20 events or when the app moves to background.
actor TelemetryService {
    static let shared = TelemetryService()

    private var buffer: [[String: AnyCodable]] = []
    private let batchSize = 20

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            Task { await self?.flush() }
        }
    }

    func track(_ eventName: String, properties: [String: AnyCodable] = [:]) async {
        var event: [String: AnyCodable] = [
            "event": .string(eventName),
            "ts": .string(ISO8601DateFormatter.ms.string(from: Date()))
        ]
        event.merge(properties) { _, new in new }
        buffer.append(event)
        if buffer.count >= batchSize { await flush() }
    }

    func flush() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer = []
        do {
            struct Body: Encodable { let events: [[String: AnyCodable]] }
            let _: Empty = try await APIClient.shared.post("telemetry", body: Body(events: batch))
        } catch {
            // Telemetry is non-critical; discard on error
        }
    }
}

/// Minimal type-erasing Codable wrapper for telemetry property values.
enum AnyCodable: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else { self = .string(try c.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        }
    }
}
