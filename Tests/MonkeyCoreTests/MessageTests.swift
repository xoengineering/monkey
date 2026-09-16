import Foundation
import Testing

@testable import MonkeyCore

@Suite struct MessageTests {
  @Test func matchesTheDocumentedOnDiskShape() throws {
    let raw = """
      ---
      id: k7x2q9
      role: user
      created_at: 2026-09-15T14:32:08.123Z
      status: complete
      model: system-on-device
      in_reply_to: ""
      tokens_prompt: 0
      tokens_output: 0
      error: ""
      ---

      Hello there.
      """
    let data = Data(raw.utf8)

    let message = try Message.load(from: data)

    #expect(message.id == MessageID(rawValue: "k7x2q9"))
    #expect(message.role == .user)
    #expect(message.status == .complete)
    #expect(message.model == "system-on-device")
    #expect(message.inReplyTo == nil)
    #expect(message.tokensPrompt == nil)
    #expect(message.tokensOutput == nil)
    #expect(message.error == nil)
    #expect(message.body == "Hello there.")
  }

  @Test func roundTripsThroughSerialization() throws {
    let original = Message(
      id: MessageID(rawValue: "k7x2q9"),
      role: .assistant,
      createdAt: try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:41.507Z")),
      status: .complete,
      model: "system-on-device",
      inReplyTo: MessageID(rawValue: "m3pd1w"),
      tokensPrompt: 12,
      tokensOutput: 34,
      error: nil,
      body: "The answer is 4."
    )

    let data = try original.serialized()
    let loaded = try Message.load(from: data)

    #expect(loaded == original)
  }

  @Test func omitsOptionalFieldsAsEmptySentinelsOnDisk() throws {
    let message = Message(
      id: MessageID(rawValue: "abc123"),
      role: .user,
      createdAt: try #require(ISO8601Milliseconds.date(from: "2026-09-15T14:32:08.123Z")),
      status: .streaming,
      model: "system-on-device",
      body: "Partial"
    )

    let data = try message.serialized()
    let text = try #require(String(data: data, encoding: .utf8))

    #expect(text.contains("in_reply_to: ''"))
    #expect(text.contains("tokens_prompt: 0"))
    #expect(text.contains("tokens_output: 0"))
    #expect(text.contains("error: ''"))
  }
}
