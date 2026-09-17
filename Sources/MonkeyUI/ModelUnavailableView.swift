import FoundationModels
import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

struct ModelUnavailableView: View {
  let reason: SystemLanguageModel.Availability.UnavailableReason

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "exclamationmark.triangle")
    } description: {
      Text(description)
    } actions: {
      if reason == .appleIntelligenceNotEnabled {
        Button("Open Settings", action: openAppleIntelligenceSettings)
      }
    }
  }

  /// **[verified]** on this machine (macOS 27.0, build 26A425): opening
  /// `x-apple.systempreferences:com.apple.preference.siri` navigates System
  /// Settings to the "Siri" pane, which on this OS version is the same pane
  /// that contains Apple Intelligence's "App Access" section and the "About
  /// Apple Intelligence & Privacy…" link — confirmed by screenshot, not
  /// guessed. This is an unofficial URL scheme, so it could change in a
  /// future OS release; there's no public API for deep-linking to a specific
  /// System Settings pane. iOS/iPadOS have no equivalent at all (Apple
  /// doesn't allow deep-linking into a specific Settings sub-page), so this
  /// opens the app's own Settings page instead — the standard, sanctioned
  /// fallback.
  private func openAppleIntelligenceSettings() {
    #if os(macOS)
      guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.siri") else {
        return
      }
      NSWorkspace.shared.open(url)
    #else
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(url)
    #endif
  }

  private var title: String {
    switch reason {
    case .deviceNotEligible: "Device Not Supported"
    case .appleIntelligenceNotEnabled: "Apple Intelligence Is Off"
    case .modelNotReady: "Model Not Ready"
    @unknown default: "Model Unavailable"
    }
  }

  private var description: String {
    switch reason {
    case .deviceNotEligible:
      "This device doesn't support Apple Intelligence, so Monkey can't run its on-device model."
    case .appleIntelligenceNotEnabled:
      "Turn on Apple Intelligence in Settings to use Monkey."
    case .modelNotReady:
      "The on-device model is still downloading or preparing. Try again shortly."
    @unknown default:
      "The on-device model isn't available right now."
    }
  }
}
