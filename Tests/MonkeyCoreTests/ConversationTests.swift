import Foundation
import Testing
import Yams

@testable import MonkeyCore

@Suite struct ConversationTests {
  @Test func matchesTheDocumentedOnDiskShape() throws {
    let raw = """
      id: 2026-09-15T14-32-08.123Z-k7x2q9
      title: Untitled
      created_at: 2026-09-15T14:32:08.123Z
      updated_at: 2026-09-15T14:32:41.507Z
      instructions: ""
      message_count: 2
      """

    let conversation = try YAMLDecoder().decode(Conversation.self, from: raw)

    #expect(conversation.id == ConversationID(rawValue: "2026-09-15T14-32-08.123Z-k7x2q9"))
    #expect(conversation.title == "Untitled")
    #expect(conversation.instructions == "")
    #expect(conversation.messageCount == 2)
  }

  @Test func roundTripsThroughYAML() throws {
    let original = Conversation(
      id: ConversationID(rawValue: "2026-09-15T14-32-08.123Z-k7x2q9"),
      title: "Weekend trip planning",
      createdAt: try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:08.123Z")),
      updatedAt: try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:41.507Z")),
      lastMessageAt: try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:40.001Z")),
      instructions: "Be concise.",
      messageCount: 4
    )

    let yaml = try YAMLEncoder().encode(original)
    let decoded = try YAMLDecoder().decode(Conversation.self, from: yaml)

    #expect(decoded == original)
  }

  @Test func lastMessageAtIsOptionalForConversationsWrittenBeforeItExisted() throws {
    let yaml = """
      id: 2026-09-15T14-32-08.123Z-k7x2q9
      title: Untitled
      created_at: 2026-09-15T14:32:08.123Z
      updated_at: 2026-09-15T14:32:41.507Z
      instructions: ""
      message_count: 0
      """

    let decoded = try YAMLDecoder().decode(Conversation.self, from: yaml)

    #expect(decoded.lastMessageAt == nil)
    #expect(decoded.lastActivityAt == decoded.createdAt)
  }

  @Test func idEqualsTheTimestampedFolderName() throws {
    let name = try #require(TimestampedName(parsing: "2026-09-15T14-32-08.123Z-k7x2q9"))
    let id = ConversationID(timestampedName: name)

    #expect(id.rawValue == "2026-09-15T14-32-08.123Z-k7x2q9")
    #expect(id.timestampedName == name)
  }
}
