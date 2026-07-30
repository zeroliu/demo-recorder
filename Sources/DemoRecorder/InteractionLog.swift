import Foundation

enum InteractionLog {
  static func start(at url: URL, timestamp: TimeInterval) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
      throw RecorderError.outputExists(url)
    }
    let entry = InteractionLogEntry(type: "session", timestamp: timestamp)
    try line(for: entry).write(to: url, atomically: true, encoding: .utf8)
  }

  static func append(_ options: MarkOptions) throws {
    guard FileManager.default.fileExists(atPath: options.eventsURL.path) else {
      throw RecorderError.invalidInteraction("The event log is not ready.")
    }
    let x = options.x / options.viewportWidth
    let y = options.y / options.viewportHeight
    guard (0...1).contains(x), (0...1).contains(y) else {
      throw RecorderError.invalidInteraction("Marker coordinates are outside the viewport.")
    }
    let entry = InteractionLogEntry(
      type: options.kind.rawValue,
      timestamp: Date().timeIntervalSince1970,
      x: x,
      y: y
    )
    let handle = try FileHandle(forWritingTo: options.eventsURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(line(for: entry).utf8))
  }

  static func load(from url: URL) throws -> [TimedInteraction] {
    let entries = try String(contentsOf: url, encoding: .utf8)
      .split(whereSeparator: \.isNewline)
      .map { try JSONDecoder().decode(InteractionLogEntry.self, from: Data($0.utf8)) }
    guard let start = entries.first(where: { $0.type == "session" })?.timestamp else {
      throw RecorderError.invalidInteraction("The event log has no session timestamp.")
    }
    return try entries.compactMap { entry in
      guard let kind = InteractionKind(rawValue: entry.type) else { return nil }
      guard let x = entry.x, let y = entry.y, entry.timestamp >= start else {
        throw RecorderError.invalidInteraction("A marker is incomplete or predates recording.")
      }
      return TimedInteraction(time: entry.timestamp - start, x: x, y: y, kind: kind)
    }
  }

  private static func line(for entry: InteractionLogEntry) throws -> String {
    String(decoding: try JSONEncoder().encode(entry), as: UTF8.self) + "\n"
  }
}

private struct InteractionLogEntry: Codable {
  let type: String
  let timestamp: TimeInterval
  var x: Double?
  var y: Double?
}
