import Foundation
import Testing

@testable import DemoRecorder

@Suite("CaptionDocument")
struct CaptionDocumentTests {
  @Test("accepts ordered positive caption ranges")
  func acceptsValidRanges() throws {
    let document = CaptionDocument(captions: [
      CaptionCue(start: 0, end: 2, text: "Type a draft", label: nil, tone: .neutral),
      CaptionCue(start: 2, end: 4, text: "Switch backend", label: "STEP 2", tone: .after),
    ])
    try document.validate()
  }

  @Test("rejects an empty caption range")
  func rejectsEmptyRange() {
    let document = CaptionDocument(captions: [
      CaptionCue(start: 2, end: 2, text: "Invalid", label: nil, tone: nil)
    ])
    #expect(throws: RecorderError.self) {
      try document.validate()
    }
  }

  @Test("decodes an optional centered caption placement")
  func decodesCenteredPlacement() throws {
    let data = Data(
      """
      {"captions":[{"start":0,"end":2,"text":"New version","placement":"center"}]}
      """.utf8
    )

    let document = try JSONDecoder().decode(CaptionDocument.self, from: data)

    #expect(document.captions[0].placement == .center)
  }
}
