import Foundation

enum Command {
  case list(ListOptions)
  case record(RecordOptions)
  case render(RenderOptions)
  case mark(MarkOptions)
}

struct ListOptions {
  let app: String?
}

struct RecordOptions {
  let app: String
  let title: String?
  let windowID: UInt32?
  let outputURL: URL
  let duration: TimeInterval?
  let captionsURL: URL?
  let eventsURL: URL?
}

struct RenderOptions {
  let inputURL: URL
  let outputURL: URL
  let captionsURL: URL?
  let eventsURL: URL?
}

struct MarkOptions {
  let eventsURL: URL
  let x: Double
  let y: Double
  let viewportWidth: Double
  let viewportHeight: Double
  let kind: InteractionKind
}

struct CaptionDocument: Codable, Sendable {
  let captions: [CaptionCue]

  func validate() throws {
    for cue in captions {
      guard cue.start >= 0, cue.end > cue.start else {
        throw RecorderError.invalidCaption(cue.text)
      }
    }
  }
}

struct CaptionCue: Codable, Sendable {
  let start: TimeInterval
  let end: TimeInterval
  let text: String
  let label: String?
  let tone: CaptionTone?
  let placement: CaptionPlacement?

  init(
    start: TimeInterval,
    end: TimeInterval,
    text: String,
    label: String?,
    tone: CaptionTone?,
    placement: CaptionPlacement? = nil
  ) {
    self.start = start
    self.end = end
    self.text = text
    self.label = label
    self.tone = tone
    self.placement = placement
  }
}

enum CaptionTone: String, Codable, Sendable {
  case neutral
  case before
  case after
}

enum CaptionPlacement: String, Codable, Sendable {
  case bottom
  case center
}

enum InteractionKind: String, Codable, Sendable {
  case move
  case click
}

struct TimedInteraction: Sendable {
  let time: TimeInterval
  let x: Double
  let y: Double
  let kind: InteractionKind
}

enum RecorderError: LocalizedError {
  case usage(String)
  case noMatchingWindow
  case ambiguousWindows
  case outputExists(URL)
  case invalidCaption(String)
  case invalidInteraction(String)
  case recordingFailed(String)
  case unsupportedVideo

  var errorDescription: String? {
    switch self {
    case .usage(let message): message
    case .noMatchingWindow: "No matching on-screen window was found."
    case .ambiguousWindows: "Multiple windows matched. Re-run with --window-id."
    case .outputExists(let url): "Output already exists: \(url.path)"
    case .invalidCaption(let text): "Invalid caption timing for “\(text)”."
    case .invalidInteraction(let message): "Invalid interaction: \(message)"
    case .recordingFailed(let message): "Recording failed: \(message)"
    case .unsupportedVideo: "The input does not contain a supported video track."
    }
  }
}
