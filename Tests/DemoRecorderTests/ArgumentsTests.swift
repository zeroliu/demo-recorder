import Foundation
import Testing

@testable import DemoRecorder

@Suite("Arguments")
struct ArgumentsTests {
  @Test("parses a window recording with captions")
  func parsesRecord() throws {
    let command = try Arguments.parse([
      "record",
      "--app", "Obsidian",
      "--window-id", "42",
      "--output", "/tmp/demo.mp4",
      "--duration", "8.5",
      "--captions", "/tmp/captions.json",
      "--events", "/tmp/events.ndjson",
    ])

    guard case .record(let options) = command else {
      Issue.record("Expected record command")
      return
    }
    #expect(options.app == "Obsidian")
    #expect(options.windowID == 42)
    #expect(options.duration == 8.5)
    #expect(options.outputURL.path == "/tmp/demo.mp4")
    #expect(options.captionsURL?.path == "/tmp/captions.json")
    #expect(options.eventsURL?.path == "/tmp/events.ndjson")
  }

  @Test("rejects a nonpositive duration")
  func rejectsDuration() {
    #expect(throws: RecorderError.self) {
      try Arguments.parse([
        "record", "--app", "Obsidian",
        "--output", "/tmp/demo.mp4",
        "--duration", "0",
      ])
    }
  }

  @Test("parses an app-filtered window listing")
  func parsesList() throws {
    let command = try Arguments.parse(["list", "--app", "Obsidian"])
    guard case .list(let options) = command else {
      Issue.record("Expected list command")
      return
    }
    #expect(options.app == "Obsidian")
  }

  @Test("parses a normalized click marker")
  func parsesMarker() throws {
    let command = try Arguments.parse([
      "mark",
      "--events", "/tmp/events.ndjson",
      "--x", "640",
      "--y", "360",
      "--viewport-width", "1280",
      "--viewport-height", "720",
    ])
    guard case .mark(let options) = command else {
      Issue.record("Expected mark command")
      return
    }
    #expect(options.kind == .click)
    #expect(options.x / options.viewportWidth == 0.5)
    #expect(options.y / options.viewportHeight == 0.5)
  }
}
