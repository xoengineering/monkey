import Foundation

public struct TimestampedName: Hashable, Sendable, Comparable, CustomStringConvertible {
  public let timestamp: Date
  public let key: String

  private static let keyAlphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
  private static let keyLength = 6
  private static let timestampLength = 24

  private static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  public init(timestamp: Date, key: String) {
    self.timestamp = timestamp
    self.key = key
  }

  public init(timestamp: Date = Date()) {
    self.init(timestamp: timestamp, key: Self.randomKey())
  }

  public init?(parsing string: String) {
    let expectedLength = Self.timestampLength + 1 + Self.keyLength
    guard string.count == expectedLength else { return nil }

    let characters = Array(string)
    guard characters[4] == "-", characters[7] == "-", characters[10] == "T",
      characters[13] == "-", characters[16] == "-", characters[19] == ".",
      characters[23] == "Z", characters[24] == "-"
    else { return nil }

    func digits(_ range: Range<Int>) -> Int? {
      Int(String(characters[range]))
    }

    guard let year = digits(0..<4), let month = digits(5..<7), let day = digits(8..<10),
      let hour = digits(11..<13), let minute = digits(14..<16), let second = digits(17..<19),
      let milliseconds = digits(20..<23)
    else { return nil }

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.nanosecond = milliseconds * 1_000_000

    guard let date = Self.utcCalendar.date(from: components) else { return nil }

    self.timestamp = date
    self.key = String(characters[25...])
  }

  public var description: String {
    let components = Self.utcCalendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: timestamp)
    let milliseconds = Int((Double(components.nanosecond ?? 0) / 1_000_000).rounded())
    let timestampString = String(
      format: "%04d-%02d-%02dT%02d-%02d-%02d.%03dZ",
      components.year ?? 0, components.month ?? 0, components.day ?? 0,
      components.hour ?? 0, components.minute ?? 0, components.second ?? 0, milliseconds)
    return "\(timestampString)-\(key)"
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.description < rhs.description
  }

  private static func randomKey() -> String {
    String((0..<keyLength).map { _ in keyAlphabet.randomElement()! })
  }
}
