import AppKit
import CoreImage
import Foundation

struct InteractionOverlayStore: @unchecked Sendable {
  private let events: [TimedInteraction]
  private let cursor: CIImage
  private let pulses: [CIImage]

  @MainActor
  init(events: [TimedInteraction]) {
    self.events = events
    cursor = InteractionArtwork.cursor()
    pulses = (0..<15).map { InteractionArtwork.pulse(progress: Double($0) / 14) }
  }

  func image(at seconds: TimeInterval, size: CGSize) -> CIImage? {
    guard let current = events.last(where: { $0.time <= seconds }) else { return nil }
    let x = current.x * size.width
    let y = (1 - current.y) * size.height
    var overlay = cursor.transformed(by: .init(translationX: x - 5, y: y - 59))

    if let click = events.last(where: {
      $0.kind == .click && seconds >= $0.time && seconds < $0.time + 0.5
    }) {
      let progress = (seconds - click.time) / 0.5
      let index = min(pulses.count - 1, max(0, Int(progress * Double(pulses.count))))
      let pulse = pulses[index].transformed(
        by: .init(
          translationX: click.x * size.width - 50,
          y: (1 - click.y) * size.height - 50
        ))
      overlay = overlay.composited(over: pulse)
    }
    return overlay
  }
}

private enum InteractionArtwork {
  @MainActor
  static func cursor() -> CIImage {
    draw(size: CGSize(width: 48, height: 64)) {
      let path = NSBezierPath()
      path.move(to: CGPoint(x: 5, y: 59))
      path.line(to: CGPoint(x: 5, y: 12))
      path.line(to: CGPoint(x: 17, y: 24))
      path.line(to: CGPoint(x: 27, y: 5))
      path.line(to: CGPoint(x: 35, y: 9))
      path.line(to: CGPoint(x: 25, y: 28))
      path.line(to: CGPoint(x: 43, y: 28))
      path.close()
      NSColor.black.setStroke()
      NSColor.white.setFill()
      path.lineWidth = 5
      path.stroke()
      path.fill()
    }
  }

  @MainActor
  static func pulse(progress: Double) -> CIImage {
    draw(size: CGSize(width: 100, height: 100)) {
      let radius = 14 + 28 * progress
      let circle = NSBezierPath(
        ovalIn: CGRect(
          x: 50 - radius,
          y: 50 - radius,
          width: radius * 2,
          height: radius * 2
        ))
      NSColor.systemYellow.withAlphaComponent(1 - progress).setStroke()
      circle.lineWidth = 7
      circle.stroke()
    }
  }

  @MainActor
  private static func draw(size: CGSize, body: () -> Void) -> CIImage {
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
    body()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return CIImage(cgImage: bitmap.cgImage!)
  }
}
