/// The `<timestamp>-<key>.md` file name of a message on disk.
public struct MessageFileName: Hashable, Sendable, Comparable, CustomStringConvertible {
  public let timestampedName: TimestampedName

  public init(timestampedName: TimestampedName) {
    self.timestampedName = timestampedName
  }

  public init?(parsing fileName: String) {
    guard fileName.hasSuffix(".md") else { return nil }
    guard let name = TimestampedName(parsing: String(fileName.dropLast(3))) else {
      return nil
    }
    self.timestampedName = name
  }

  public var id: MessageID { MessageID(rawValue: timestampedName.key) }

  public var description: String { "\(timestampedName).md" }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.timestampedName < rhs.timestampedName
  }
}
