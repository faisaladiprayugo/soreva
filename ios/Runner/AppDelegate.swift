import AppIntents
import Flutter
import UIKit
import Vision

// =============================================================================
// STAGE 0A SPIKE — THROWAWAY CODE
//
// Deliberately all in AppDelegate.swift so the spike needs:
//   - no new Xcode target
//   - no App Group entitlement
//   - no project.pbxproj surgery
//
// The intent lives in the main app target, so it writes to the app's OWN
// container. Stage 0C rebuilds this properly as a separate target writing to
// the App Group inbox per PRD §7.6.
//
// Purpose: answer the five gating questions in PRD §5.2 on a real device.
// The intent returns a DIALOG so results are visible without a debugger.
// =============================================================================

/// Spike inbox: app-container-local, not the App Group.
enum SpikeInbox {
  static func directory() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("soreva_spike_inbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  /// Atomic write: temp file, then rename.
  static func write(_ record: [String: Any], id: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) else { return }
    let dir = directory()
    let tmp = dir.appendingPathComponent("\(id).json.tmp")
    let final = dir.appendingPathComponent("\(id).json")
    try? data.write(to: tmp, options: .atomic)
    try? FileManager.default.moveItem(at: tmp, to: final)
  }

  static func listJSON() -> [String] {
    let dir = directory()
    let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    return files
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
      .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
  }

  static func clear() {
    let dir = directory()
    let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    for f in files { try? FileManager.default.removeItem(at: f) }
  }
}

/// On-device OCR via Apple Vision. Free, no network, no API key.
enum SpikeOCR {
  struct Result {
    var text: String
    var blockCount: Int
    var meanConfidence: Double
    var supportedLanguages: [String]
    var usedLanguages: [String]
    var error: String?
  }

  static func recognize(imageData: Data) -> Result {
    guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
      return Result(text: "", blockCount: 0, meanConfidence: 0, supportedLanguages: [],
                    usedLanguages: [], error: "could not decode image data")
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Receipts are merchant names and numbers — autocorrection hurts more than helps.
    request.usesLanguageCorrection = false
    request.automaticallyDetectsLanguage = true

    // Phase 0 data point: does Vision actually support Indonesian on this device?
    let supported = (try? request.supportedRecognitionLanguages()) ?? []

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return Result(text: "", blockCount: 0, meanConfidence: 0, supportedLanguages: supported,
                    usedLanguages: request.recognitionLanguages, error: "\(error)")
    }

    let observations = request.results ?? []
    let candidates = observations.compactMap { $0.topCandidates(1).first }
    let text = candidates.map { $0.string }.joined(separator: "\n")
    let confidences = candidates.map { Double($0.confidence) }
    let mean = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)

    return Result(text: text, blockCount: observations.count, meanConfidence: mean,
                  supportedLanguages: supported, usedLanguages: request.recognitionLanguages,
                  error: nil)
  }
}

@available(iOS 18.2, *)
struct SorevaCaptureSpikeIntent: AppIntent {
  static var title: LocalizedStringResource = "Capture Expense (Spike)"
  static var description = IntentDescription(
    "Stage 0A spike. Receives a screenshot and the current app name, runs on-device Vision OCR, and writes a capture record."
  )

  /// Critical for the spike: the app must NOT come to the foreground.
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Screenshot", supportedTypeIdentifiers: ["public.image"])
  var screenshot: IntentFile?

  @Parameter(title: "Current App")
  var currentApp: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let startedAt = Date()
    let captureId = UUID().uuidString

    let reportedApp = (currentApp?.isEmpty == false) ? currentApp! : "<none passed>"
    var ocr = SpikeOCR.Result(text: "", blockCount: 0, meanConfidence: 0,
                              supportedLanguages: [], usedLanguages: [], error: nil)
    var imageBytes = 0

    if let file = screenshot {
      let data = file.data
      imageBytes = data.count
      ocr = SpikeOCR.recognize(imageData: data)
    } else {
      ocr.error = "no screenshot passed to the intent"
    }

    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)

    // Mirrors the PRD §7.6 inbox schema, plus spike-only diagnostics.
    let record: [String: Any] = [
      "capture_attempt_id": captureId,
      "created_at": ISO8601DateFormatter().string(from: startedAt),
      "route": "shortcut_intent",
      "input_kind": screenshot == nil ? "none" : "image",
      "raw_text": ocr.text,
      "ocr_engine": "vision",
      "ocr_block_count": ocr.blockCount,
      "ocr_mean_confidence": ocr.meanConfidence,
      "foreground_app_name": currentApp ?? NSNull(),
      "foreground_app_id": NSNull(),
      "attribution_source": currentApp == nil ? "unavailable" : "get_current_app",
      "schema_version": 1,
      // spike diagnostics
      "spike_image_bytes": imageBytes,
      "spike_elapsed_ms": elapsedMs,
      "spike_vision_supported_languages": ocr.supportedLanguages,
      "spike_vision_used_languages": ocr.usedLanguages,
      "spike_error": ocr.error ?? NSNull(),
    ]
    SpikeInbox.write(record, id: captureId)

    // Visible on-device feedback — this is how the gating questions get answered.
    let preview = ocr.text
      .replacingOccurrences(of: "\n", with: " / ")
      .prefix(90)

    let dialog: String
    if let err = ocr.error {
      dialog = "App: \(reportedApp)\nFAILED: \(err)\n\(elapsedMs)ms"
    } else {
      dialog = """
      App: \(reportedApp)
      OCR: \(ocr.text.count) chars, \(ocr.blockCount) blocks, conf \(String(format: "%.2f", ocr.meanConfidence))
      Image: \(imageBytes / 1024)KB · \(elapsedMs)ms
      "\(preview)…"
      """
    }

    return .result(dialog: IntentDialog(stringLiteral: dialog))
  }
}

@available(iOS 18.2, *)
struct SorevaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SorevaCaptureSpikeIntent(),
      phrases: ["Capture expense in \(.applicationName)"],
      shortTitle: "Capture Expense",
      systemImageName: "doc.text.viewfinder"
    )
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Spike-only channel so the Dart side can read back what the intent wrote.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "soreva/spike",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "listCaptures":
          result(SpikeInbox.listJSON())
        case "clearCaptures":
          SpikeInbox.clear()
          result(nil)
        case "inboxPath":
          result(SpikeInbox.directory().path)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
