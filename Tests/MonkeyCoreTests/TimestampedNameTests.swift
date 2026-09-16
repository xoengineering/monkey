import Foundation
import Testing

@testable import MonkeyCore

@Suite struct TimestampedNameTests {
  @Test func formatsWithHyphensInPlaceOfColons() throws {
    let name = try #require(TimestampedName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9"))
    #expect(name.description == "2026-09-15T14-32-08.123Z-k7x2q9")
  }

  @Test func roundTripsThroughParsing() throws {
    let original = try #require(TimestampedName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9"))
    let parsed = try #require(TimestampedName(parsing: original.description))
    #expect(parsed == original)
  }

  @Test func rejectsMalformedStrings() {
    #expect(TimestampedName(parsing: "") == nil)
    #expect(TimestampedName(parsing: "not-a-timestamp-at-all") == nil)
    #expect(TimestampedName(parsing: "2026-09-15T14-32-08.123Z") == nil)
    #expect(TimestampedName(parsing: "2026-09-15T14:32:08.123Z-k7x2q9") == nil)
  }

  @Test func generatesRandomLowercaseAlphanumericKeys() {
    let name = TimestampedName(timestamp: Date())
    #expect(name.key.count == 6)
    #expect(name.key.allSatisfy { $0.isLowercase || $0.isNumber })
  }

  @Test func lexicalSortMatchesChronologicalOrder() throws {
    let earlier = try #require(
      TimestampedName(parsing: "2026-09-15T14-32-08.123Z-aaaaaa"))
    let later = try #require(
      TimestampedName(parsing: "2026-09-15T14-32-08.124Z-aaaaaa"))
    let sameMillisecondDifferentKey = try #require(
      TimestampedName(parsing: "2026-09-15T14-32-08.124Z-zzzzzz"))

    #expect(earlier < later)
    #expect(later < sameMillisecondDifferentKey)

    let sorted = [sameMillisecondDifferentKey, earlier, later].sorted()
    #expect(
      sorted.map(\.description)
        == [earlier, later, sameMillisecondDifferentKey].map(\.description))
  }
}
