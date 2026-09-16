/// The full `<timestamp>-<key>` folder name, e.g. `2026-09-15T14-32-08.123Z-k7x2q9`.
public struct ConversationID: Hashable, Sendable, Codable, RawRepresentable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension ConversationID: CustomStringConvertible {
  public var description: String { rawValue }
}
