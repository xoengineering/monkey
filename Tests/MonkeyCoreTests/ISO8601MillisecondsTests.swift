import Foundation
import Testing

@testable import MonkeyCore

@Suite struct ISO8601MillisecondsTests {
  @Test func formatsWithColonsAndThreeDigitMilliseconds() throws {
    let date = try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:08.123Z"))
    #expect(ISO8601Milliseconds.string(from: date) == "2026-09-15T14:32:08.123Z")
  }

  @Test func roundTripsThroughParsing() throws {
    let original = try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:08.999Z"))
    let formatted = ISO8601Milliseconds.string(from: original)
    let reparsed = try #require(ISO8601Milliseconds.date(from: formatted))
    #expect(reparsed == original)
  }

  @Test func rejectsMalformedStrings() {
    #expect(ISO8601Milliseconds.date(from: "") == nil)
    #expect(ISO8601Milliseconds.date(from: "2026-09-15T14-32-08.123Z") == nil)
    #expect(ISO8601Milliseconds.date(from: "not a date") == nil)
  }
}
