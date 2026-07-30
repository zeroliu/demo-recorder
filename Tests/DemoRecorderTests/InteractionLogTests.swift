import Foundation
import Testing

@testable import DemoRecorder

@Suite("InteractionLog")
struct InteractionLogTests {
  @Test("stores marker time and normalized viewport coordinates")
  func storesNormalizedMarker() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("interaction-log-\(UUID().uuidString).ndjson")
    defer { try? FileManager.default.removeItem(at: url) }

    try InteractionLog.start(at: url, timestamp: Date().timeIntervalSince1970 - 1)
    try InteractionLog.append(
      MarkOptions(
        eventsURL: url,
        x: 640,
        y: 180,
        viewportWidth: 1280,
        viewportHeight: 720,
        kind: .click
      ))

    let events = try InteractionLog.load(from: url)
    #expect(events.count == 1)
    #expect(events[0].time >= 1)
    #expect(events[0].x == 0.5)
    #expect(events[0].y == 0.25)
    #expect(events[0].kind == .click)
  }
}
