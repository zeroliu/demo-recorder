import CoreGraphics
import Testing

@testable import DemoRecorder

@Suite("CaptionLayout")
struct CaptionLayoutTests {
  @Test("centers a measured line vertically inside its drawing frame")
  func centersTextVertically() {
    let frame = CGRect(x: 10, y: 20, width: 100, height: 60)

    let centered = CaptionLayout.verticallyCenteredFrame(contentHeight: 24, in: frame)

    #expect(centered == CGRect(x: 10, y: 38, width: 100, height: 24))
  }
}
