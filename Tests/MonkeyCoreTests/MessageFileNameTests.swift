import Foundation
import Testing

@testable import MonkeyCore

@Suite struct MessageFileNameTests {
  @Test func formatsWithMDExtension() throws {
    let timestampedName = try #require(
      TimestampedName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9"))
    let fileName = MessageFileName(timestampedName: timestampedName)

    #expect(fileName.description == "2026-09-15T14-32-08.123Z-k7x2q9.md")
  }

  @Test func parsesFromAFileNameString() throws {
    let fileName = try #require(
      MessageFileName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9.md"))

    #expect(fileName.id == MessageID(rawValue: "k7x2q9"))
  }

  @Test func rejectsNamesWithoutMDExtension() {
    #expect(MessageFileName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9.txt") == nil)
  }

  @Test func rejectsNamesWithInvalidTimestampedNamePortion() {
    #expect(MessageFileName(parsing: "not-a-valid-name.md") == nil)
  }

  @Test func sortsChronologically() throws {
    let earlier = try #require(
      MessageFileName(parsing: "2026-09-15T14-32-08.123Z-aaaaaa.md"))
    let later = try #require(
      MessageFileName(parsing: "2026-09-15T14-32-08.124Z-aaaaaa.md"))

    #expect(earlier < later)
  }
}
