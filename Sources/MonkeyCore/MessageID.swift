/// The 6-character key portion of a message's `<timestamp>-<key>` file name,
/// e.g. `k7x2q9`. This is the `id` stored in a message's frontmatter.
public struct MessageID: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public var description: String { rawValue }
}
