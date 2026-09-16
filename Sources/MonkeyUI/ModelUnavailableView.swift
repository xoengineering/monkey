import FoundationModels
import SwiftUI

struct ModelUnavailableView: View {
  let reason: SystemLanguageModel.Availability.UnavailableReason

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "exclamationmark.triangle")
    } description: {
      Text(description)
    }
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
