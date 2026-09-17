import Foundation

/// Formats and parses dates as UTC ISO-8601 with exactly three fractional digits
/// (e.g. `2026-09-15T14:32:08.123Z`), matching the on-disk frontmatter format.
///
/// `Date.ISO8601FormatStyle` truncates rather than rounds fractional seconds in
/// some cases (e.g. `.124` round-trips to `.123`), so formatting is done manually
/// via `Calendar` components, rounding milliseconds to the nearest whole value.
public enum ISO8601Milliseconds {
  private static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  public static func string(from date: Date) -> String {
    let components = utcCalendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
    let milliseconds = Int((Double(components.nanosecond ?? 0) / 1_000_000).rounded())
    return String(
      format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
      components.year ?? 0, components.month ?? 0, components.day ?? 0,
      components.hour ?? 0, components.minute ?? 0, components.second ?? 0, milliseconds)
  }

  public static func date(from string: String) -> Date? {
    guard string.count == 24 else { return nil }

    let characters = Array(string)
    guard characters[4] == "-", characters[7] == "-", characters[10] == "T",
      characters[13] == ":", characters[16] == ":", characters[19] == ".",
      characters[23] == "Z"
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

    return utcCalendar.date(from: components)
  }
}
