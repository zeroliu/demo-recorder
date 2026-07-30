import AVFoundation
import AppKit
import CoreImage
import Foundation

enum CaptionRenderer {
  static func render(_ options: RenderOptions) async throws {
    guard !FileManager.default.fileExists(atPath: options.outputURL.path) else {
      throw RecorderError.outputExists(options.outputURL)
    }
    let captions: [CaptionCue] =
      try options.captionsURL.map { url in
        let document = try JSONDecoder().decode(
          CaptionDocument.self,
          from: Data(contentsOf: url)
        )
        try document.validate()
        return document.captions
      } ?? []
    let interactions: [TimedInteraction] =
      try options.eventsURL.map(InteractionLog.load(from:)) ?? []

    let asset = AVURLAsset(url: options.inputURL)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard let track = tracks.first else { throw RecorderError.unsupportedVideo }

    let naturalSize = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let renderSize = CGRect(origin: .zero, size: naturalSize).applying(transform).standardized.size
    let overlays = await MainActor.run {
      (
        captions: OverlayStore(cues: captions, size: renderSize),
        interactions: InteractionOverlayStore(events: interactions)
      )
    }
    let composition = try await AVMutableVideoComposition.videoComposition(with: asset) { request in
      let seconds = request.compositionTime.seconds
      var output = request.sourceImage
      if let caption = overlays.captions.image(at: seconds, size: request.renderSize) {
        output = caption.composited(over: output)
      }
      if let interaction = overlays.interactions.image(at: seconds, size: request.renderSize) {
        output = interaction.composited(over: output)
      }
      request.finish(with: output.cropped(to: request.sourceImage.extent), context: nil)
    }

    guard
      let exporter = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetHighestQuality
      )
    else {
      throw RecorderError.unsupportedVideo
    }
    exporter.videoComposition = composition
    try await exporter.export(to: options.outputURL, as: .mp4)
  }
}

private struct OverlayStore: @unchecked Sendable {
  private let entries: [OverlayEntry]

  @MainActor
  init(cues: [CaptionCue], size: CGSize) {
    entries = cues.map { cue in
      OverlayEntry(cue: cue, image: CaptionImage.make(cue: cue, size: size))
    }
  }

  func image(at seconds: TimeInterval, size: CGSize) -> CIImage? {
    entries.first {
      seconds >= $0.cue.start && seconds < $0.cue.end
    }?.image
  }
}

private struct OverlayEntry {
  let cue: CaptionCue
  let image: CIImage
}

private enum CaptionImage {
  @MainActor
  static func make(cue: CaptionCue, size: CGSize) -> CIImage {
    let scale = max(0.65, size.width / 1920)
    let height = 88 * scale
    let width = min(size.width - 80 * scale, 1180 * scale)
    let frameY =
      cue.placement == .center
      ? (size.height - height) / 2
      : 32 * scale
    let frame = CGRect(
      x: (size.width - width) / 2,
      y: frameY,
      width: width,
      height: height
    )
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(size.width),
      pixelsHigh: Int(size.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    NSColor.black.withAlphaComponent(0.82).setFill()
    NSBezierPath(roundedRect: frame, xRadius: 18 * scale, yRadius: 18 * scale).fill()

    let label = cue.label ?? cue.tone?.rawValue.uppercased()
    var textX = frame.minX + 28 * scale
    if let label {
      let labelWidth = max(110 * scale, CGFloat(label.count) * 18 * scale)
      let labelFrame = CGRect(
        x: textX,
        y: frame.minY + 18 * scale,
        width: labelWidth,
        height: 52 * scale
      )
      toneColor(cue.tone).setFill()
      NSBezierPath(roundedRect: labelFrame, xRadius: 12 * scale, yRadius: 12 * scale).fill()
      draw(label, in: labelFrame, size: 22 * scale, weight: .bold, centered: true)
      textX = labelFrame.maxX + 24 * scale
    }
    let textFrame = CGRect(
      x: textX,
      y: frame.minY + 17 * scale,
      width: frame.maxX - textX - 24 * scale,
      height: 54 * scale
    )
    draw(cue.text, in: textFrame, size: 28 * scale, weight: .semibold, centered: false)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return CIImage(cgImage: bitmap.cgImage!)
  }

  private static func draw(
    _ text: String,
    in frame: CGRect,
    size: CGFloat,
    weight: NSFont.Weight,
    centered: Bool
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: NSColor.white,
      .paragraphStyle: paragraph,
    ]
    let contentHeight = ceil((text as NSString).size(withAttributes: attributes).height)
    let drawingFrame = CaptionLayout.verticallyCenteredFrame(
      contentHeight: min(contentHeight, frame.height),
      in: frame
    )
    (text as NSString).draw(in: drawingFrame, withAttributes: attributes)
  }

  private static func toneColor(_ tone: CaptionTone?) -> NSColor {
    switch tone {
    case .before: NSColor.systemRed
    case .after: NSColor.systemGreen
    case .neutral, nil: NSColor.systemBlue
    }
  }
}

enum CaptionLayout {
  static func verticallyCenteredFrame(contentHeight: CGFloat, in frame: CGRect) -> CGRect {
    CGRect(
      x: frame.minX,
      y: frame.midY - contentHeight / 2,
      width: frame.width,
      height: contentHeight
    )
  }
}
