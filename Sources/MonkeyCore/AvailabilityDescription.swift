import FoundationModels

extension SystemLanguageModel.Availability.UnavailableReason {
  /// Plain-text description for non-UI surfaces (the CLI). MonkeyUI's
  /// `ModelUnavailableView` has its own SwiftUI-flavored title/description
  /// pair; this is the same information for `print()`.
  public var plainTextDescription: String {
    switch self {
    case .deviceNotEligible:
      "This device doesn't support Apple Intelligence."
    case .appleIntelligenceNotEnabled:
      "Apple Intelligence is turned off. Enable it in System Settings."
    case .modelNotReady:
      "The on-device model is still downloading or preparing. Try again shortly."
    @unknown default:
      "The on-device model isn't available right now."
    }
  }
}
