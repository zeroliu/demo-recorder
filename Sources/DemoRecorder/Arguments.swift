import Foundation

enum Arguments {
  static func parse(_ values: [String]) throws -> Command {
    guard let subcommand = values.first else {
      throw RecorderError.usage(usage)
    }
    let options = try KeyValues(Array(values.dropFirst()))
    switch subcommand {
    case "list":
      return .list(ListOptions(app: options.optional("--app")))
    case "record":
      return .record(
        RecordOptions(
          app: try options.required("--app"),
          title: options.optional("--title"),
          windowID: try options.optionalUInt32("--window-id"),
          outputURL: try options.requiredURL("--output"),
          duration: try options.optionalDouble("--duration"),
          captionsURL: try options.optionalURL("--captions"),
          eventsURL: try options.optionalURL("--events")
        ))
    case "render":
      let render = RenderOptions(
        inputURL: try options.requiredURL("--input"),
        outputURL: try options.requiredURL("--output"),
        captionsURL: try options.optionalURL("--captions"),
        eventsURL: try options.optionalURL("--events")
      )
      guard render.captionsURL != nil || render.eventsURL != nil else {
        throw RecorderError.usage("Render requires --captions or --events.")
      }
      return .render(render)
    case "mark":
      return .mark(
        MarkOptions(
          eventsURL: try options.requiredURL("--events"),
          x: try options.requiredDouble("--x"),
          y: try options.requiredDouble("--y"),
          viewportWidth: try options.requiredPositiveDouble("--viewport-width"),
          viewportHeight: try options.requiredPositiveDouble("--viewport-height"),
          kind: try options.interactionKind()
        ))
    default:
      throw RecorderError.usage(usage)
    }
  }

  static let usage = """
    Usage:
      demo-recorder list [--app APP]
      demo-recorder record --app APP [--title TITLE | --window-id ID]
        --output FILE [--duration SECONDS] [--captions FILE] [--events FILE]
      demo-recorder mark --events FILE --x X --y Y
        --viewport-width WIDTH --viewport-height HEIGHT [--kind click|move]
      demo-recorder render --input FILE --output FILE
        [--captions FILE] [--events FILE]
    """
}

private struct KeyValues {
  private let values: [String: String]

  init(_ arguments: [String]) throws {
    guard arguments.count.isMultiple(of: 2) else {
      throw RecorderError.usage(Arguments.usage)
    }
    var parsed: [String: String] = [:]
    for index in stride(from: 0, to: arguments.count, by: 2) {
      let key = arguments[index]
      guard key.hasPrefix("--"), parsed[key] == nil else {
        throw RecorderError.usage(Arguments.usage)
      }
      parsed[key] = arguments[index + 1]
    }
    values = parsed
  }

  func required(_ key: String) throws -> String {
    guard let value = values[key] else {
      throw RecorderError.usage("Missing \(key).\n\n\(Arguments.usage)")
    }
    return value
  }

  func optional(_ key: String) -> String? { values[key] }

  func requiredURL(_ key: String) throws -> URL {
    URL(fileURLWithPath: try required(key)).standardizedFileURL
  }

  func optionalURL(_ key: String) throws -> URL? {
    optional(key).map { URL(fileURLWithPath: $0).standardizedFileURL }
  }

  func optionalDouble(_ key: String) throws -> Double? {
    guard let raw = optional(key), let value = Double(raw), value > 0 else {
      if optional(key) == nil { return nil }
      throw RecorderError.usage("\(key) must be a positive number.")
    }
    return value
  }

  func requiredDouble(_ key: String) throws -> Double {
    guard let value = Double(try required(key)) else {
      throw RecorderError.usage("\(key) must be a number.")
    }
    return value
  }

  func requiredPositiveDouble(_ key: String) throws -> Double {
    let value = try requiredDouble(key)
    guard value > 0 else {
      throw RecorderError.usage("\(key) must be a positive number.")
    }
    return value
  }

  func interactionKind() throws -> InteractionKind {
    guard let raw = optional("--kind") else { return .click }
    guard let kind = InteractionKind(rawValue: raw) else {
      throw RecorderError.usage("--kind must be click or move.")
    }
    return kind
  }

  func optionalUInt32(_ key: String) throws -> UInt32? {
    guard let raw = optional(key), let value = UInt32(raw) else {
      if optional(key) == nil { return nil }
      throw RecorderError.usage("\(key) must be an unsigned integer.")
    }
    return value
  }
}
