import ScreenCaptureKit

enum WindowCatalog {
  static func list(_ options: ListOptions) async throws {
    let windows = try await matchingWindows(app: options.app, title: nil)
    for window in windows.sorted(by: { $0.windowID < $1.windowID }) {
      let owner = window.owningApplication?.applicationName ?? "Unknown"
      let bundle = window.owningApplication?.bundleIdentifier ?? "unknown"
      let title = window.title ?? "Untitled"
      let filter = SCContentFilter(desktopIndependentWindow: window)
      let size = "\(Int(filter.contentRect.width))x\(Int(filter.contentRect.height))"
      print("\(window.windowID)\t\(size)@\(filter.pointPixelScale)x\t\(owner)\t\(bundle)\t\(title)")
    }
  }

  static func resolve(_ options: RecordOptions) async throws -> SCWindow {
    let windows = try await matchingWindows(app: options.app, title: options.title)
    if let windowID = options.windowID {
      guard let window = windows.first(where: { $0.windowID == windowID }) else {
        throw RecorderError.noMatchingWindow
      }
      return window
    }
    guard !windows.isEmpty else { throw RecorderError.noMatchingWindow }
    guard windows.count == 1 else {
      printMatches(windows)
      throw RecorderError.ambiguousWindows
    }
    return windows[0]
  }

  private static func matchingWindows(app: String?, title: String?) async throws -> [SCWindow] {
    let content = try await SCShareableContent.excludingDesktopWindows(
      true,
      onScreenWindowsOnly: true
    )
    return content.windows.filter { window in
      guard window.frame.width > 1, window.frame.height > 1 else { return false }
      let owner = window.owningApplication
      let appMatches =
        app.map { query in
          owner?.applicationName.localizedCaseInsensitiveContains(query) == true
            || owner?.bundleIdentifier.localizedCaseInsensitiveContains(query) == true
        } ?? true
      let titleMatches =
        title.map {
          window.title?.localizedCaseInsensitiveContains($0) == true
        } ?? true
      return appMatches && titleMatches
    }
  }

  private static func printMatches(_ windows: [SCWindow]) {
    FileHandle.standardError.write(Data("Matching windows:\n".utf8))
    for window in windows {
      let title = window.title ?? "Untitled"
      FileHandle.standardError.write(Data("  \(window.windowID)\t\(title)\n".utf8))
    }
  }
}
