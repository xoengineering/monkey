import Foundation

/// `UserDefaults` keys and defaults for the General settings tab.
public enum GeneralSettings {
  /// The composer's starting height, in lines of text.
  public static let startingLinesKey = "composerStartingLines"
  public static let defaultStartingLines = 3
  public static let startingLinesRange = 1...20
}
