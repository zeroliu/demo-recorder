import AppKit
import Foundation

@main
struct DemoRecorder {
  static func main() async {
    do {
      await MainActor.run {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
      }
      let command = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))
      switch command {
      case .list(let options):
        try await WindowCatalog.list(options)
      case .record(let options):
        try await RecordingWorkflow.run(options)
      case .render(let options):
        try await CaptionRenderer.render(options)
      case .mark(let options):
        try InteractionLog.append(options)
      }
    } catch {
      FileHandle.standardError.write(Data("error: \(error)\n".utf8))
      exit(1)
    }
  }
}
