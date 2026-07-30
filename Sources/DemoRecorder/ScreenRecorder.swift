import AVFoundation
import CoreVideo
import Foundation
import ScreenCaptureKit

enum RecordingWorkflow {
  static func run(_ options: RecordOptions) async throws {
    guard !FileManager.default.fileExists(atPath: options.outputURL.path) else {
      throw RecorderError.outputExists(options.outputURL)
    }
    if let eventsURL = options.eventsURL,
      FileManager.default.fileExists(atPath: eventsURL.path)
    {
      throw RecorderError.outputExists(eventsURL)
    }
    let window = try await WindowCatalog.resolve(options)
    let hasOverlays = options.captionsURL != nil || options.eventsURL != nil
    let rawURL =
      !hasOverlays
      ? options.outputURL
      : FileManager.default.temporaryDirectory
        .appendingPathComponent("demo-recorder-\(UUID().uuidString).mp4")

    print("Recording window \(window.windowID): \(window.title ?? "Untitled")")
    try await ScreenRecorder.record(
      window: window,
      outputURL: rawURL,
      duration: options.duration,
      showsSystemCursor: options.eventsURL == nil
    ) { startedAt in
      guard let eventsURL = options.eventsURL else { return }
      try InteractionLog.start(at: eventsURL, timestamp: startedAt.timeIntervalSince1970)
      print("Ready for markers: \(eventsURL.path)")
      fflush(stdout)
    }

    if hasOverlays {
      try await CaptionRenderer.render(
        RenderOptions(
          inputURL: rawURL,
          outputURL: options.outputURL,
          captionsURL: options.captionsURL,
          eventsURL: options.eventsURL
        ))
      try? FileManager.default.removeItem(at: rawURL)
    }
    print("Saved \(options.outputURL.path)")
  }
}

enum ScreenRecorder {
  static func record(
    window: SCWindow,
    outputURL: URL,
    duration: TimeInterval?,
    showsSystemCursor: Bool = true,
    onStarted: (Date) throws -> Void = { _ in }
  ) async throws {
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let streamConfiguration = SCStreamConfiguration()
    let scale = Double(filter.pointPixelScale)
    let nativeWidth = Double(filter.contentRect.width) * scale
    let nativeHeight = Double(filter.contentRect.height) * scale
    let outputScale = min(1, 1920 / nativeWidth)
    streamConfiguration.width = even(Int(nativeWidth * outputScale))
    streamConfiguration.height = even(Int(nativeHeight * outputScale))
    streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
    streamConfiguration.queueDepth = 6
    streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
    streamConfiguration.captureResolution = .best
    streamConfiguration.showsCursor = showsSystemCursor
    streamConfiguration.showMouseClicks = showsSystemCursor
    print("Capture size: \(streamConfiguration.width)x\(streamConfiguration.height) BGRA")

    let writer = try SampleWriter(
      outputURL: outputURL,
      width: streamConfiguration.width,
      height: streamConfiguration.height
    )
    let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: nil)
    try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: writer.queue)
    try await stream.startCapture()
    do {
      try writer.waitForStart()
      try onStarted(Date())

      if let duration {
        try await Task.sleep(for: .seconds(duration))
      } else {
        print("Press Return to stop recording.")
        _ = readLine()
      }

      try await stream.stopCapture()
      try await writer.finish()
    } catch {
      try? await stream.stopCapture()
      throw error
    }
  }

  private static func even(_ value: Int) -> Int {
    max(2, value - value % 2)
  }
}

private final class SampleWriter: NSObject, SCStreamOutput, @unchecked Sendable {
  let queue = DispatchQueue(label: "DemoRecorder.SampleWriter")

  private let started = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private var didStart = false
  private var lastFrame: CMSampleBuffer?
  private var failure: Error?

  init(outputURL: URL, width: Int, height: Int) throws {
    writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: 8_000_000,
          AVVideoExpectedSourceFrameRateKey: 30,
          AVVideoMaxKeyFrameIntervalKey: 60,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ]
    )
    input.expectsMediaDataInRealTime = true
    guard writer.canAdd(input) else {
      throw RecorderError.recordingFailed("The H.264 writer rejected its video input.")
    }
    writer.add(input)
  }

  func waitForStart() throws {
    guard started.wait(timeout: .now() + 10) == .success else {
      throw RecorderError.recordingFailed("Timed out while starting.")
    }
    try throwFailure()
  }

  func stream(
    _ stream: SCStream,
    didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .screen, sampleBuffer.isValid, sampleBuffer.dataReadiness == .ready else {
      return
    }
    guard
      let attachments = CMSampleBufferGetSampleAttachmentsArray(
        sampleBuffer,
        createIfNecessary: false
      ) as? [[SCStreamFrameInfo: Any]]
    else {
      return
    }
    guard let statusRaw = attachments.first?[.status] as? Int,
      SCFrameStatus(rawValue: statusRaw) == .complete
    else {
      return
    }
    if !didStart {
      guard writer.startWriting() else {
        fail(writer.error ?? RecorderError.recordingFailed("Unable to start the H.264 writer."))
        return
      }
      writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
      didStart = true
      started.signal()
    }
    guard input.isReadyForMoreMediaData else { return }
    if !input.append(sampleBuffer) {
      let detail = writer.error.map { String(reflecting: $0) } ?? "unknown writer error"
      fail(RecorderError.recordingFailed("Unable to append a video frame: \(detail)"))
    } else {
      lastFrame = sampleBuffer
    }
  }

  func finish() async throws {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { [self] in
        appendFinalFrame()
        input.markAsFinished()
        writer.finishWriting { [self] in
          if writer.status == .completed {
            continuation.resume()
          } else {
            continuation.resume(
              throwing: RecorderError.recordingFailed(
                writer.error?.localizedDescription ?? "Unable to finalize the MP4."
              ))
          }
        }
      }
    }
    try throwFailure()
  }

  private func fail(_ error: Error) {
    let wasEmpty = lock.withLock {
      if failure == nil {
        failure = error
        return true
      }
      return false
    }
    if wasEmpty { started.signal() }
  }

  private func appendFinalFrame() {
    guard didStart, let lastFrame, input.isReadyForMoreMediaData else { return }
    var timing = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: 30),
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
      decodeTimeStamp: .invalid
    )
    var copy: CMSampleBuffer?
    let status = CMSampleBufferCreateCopyWithNewTiming(
      allocator: kCFAllocatorDefault,
      sampleBuffer: lastFrame,
      sampleTimingEntryCount: 1,
      sampleTimingArray: &timing,
      sampleBufferOut: &copy
    )
    if status == noErr, let copy, !input.append(copy) {
      fail(writer.error ?? RecorderError.recordingFailed("Unable to append the final frame."))
    }
  }

  private func throwFailure() throws {
    if let error = lock.withLock({ failure }) {
      throw RecorderError.recordingFailed(error.localizedDescription)
    }
  }
}
