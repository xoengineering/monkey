import Foundation

/// The General settings that shape the composer (message field).
public enum ComposerSettings {
  /// `UserDefaults` key for the composer's starting height, in lines of text.
  public static let startingLinesKey = "composerStartingLines"
  public static let defaultStartingLines = 3
  public static let startingLinesRange = 1...20
}
