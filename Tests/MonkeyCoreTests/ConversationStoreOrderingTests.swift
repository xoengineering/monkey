import Foundation
import Testing

@testable import MonkeyCore

@Suite struct ConversationStoreOrderingTests {
  private func makeTemporaryRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ConversationStoreOrderingTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func listsConversationsByLatestMessageDescending() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)

    var first = try await store.create(title: "First")
    var second = try await store.create(title: "Second")
    first.lastMessageAt = Date(timeIntervalSinceNow: -10)
    second.lastMessageAt = Date()
    try await store.update(first)
    try await store.update(second)

    let listed = try await store.listConversations()

    #expect(listed.map(\.title) == ["Second", "First"])
  }

  @Test func listsConversationsWithoutMessagesByCreationDate() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)

    var older = try await store.create(title: "Older")
    var newer = try await store.create(title: "Newer")
    older.createdAt = Date(timeIntervalSinceNow: -10)
    newer.createdAt = Date()
    try await store.update(older)
    try await store.update(newer)

    let listed = try await store.listConversations()

    #expect(listed.map(\.title) == ["Newer", "Older"])
  }

  @Test func backfillsLastMessageAtFromTheNewestMessageFileWhenAbsent() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let created = try await store.create(title: "Legacy")
    let name = TimestampedName(timestamp: Date(timeIntervalSinceNow: -60))
    let message = Message(
      id: MessageID(rawValue: name.key),
      role: .user,
      createdAt: name.timestamp,
      status: .complete,
      model: "system-on-device",
      body: "Written before last_message_at existed."
    )
    try await store.write(message, in: created.id)
    // Rewrite the YAML the way an older build would have left it.
    var legacy = created
    legacy.lastMessageAt = nil
    legacy.messageCount = 1
    try await store.update(legacy)

    let listed = try #require(try await store.listConversations().first)

    let lastMessageAt = try #require(listed.lastMessageAt)
    #expect(
      ISO8601Milliseconds.string(from: lastMessageAt)
        == ISO8601Milliseconds.string(from: name.timestamp))
  }

  @Test func renamingDoesNotReorderConversations() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)

    var quiet = try await store.create(title: "Quiet")
    var active = try await store.create(title: "Active")
    quiet.lastMessageAt = Date(timeIntervalSinceNow: -10)
    active.lastMessageAt = Date()
    try await store.update(quiet)
    try await store.update(active)

    quiet.title = "Quiet, renamed"
    quiet.updatedAt = Date(timeIntervalSinceNow: 10)
    try await store.update(quiet)

    let listed = try await store.listConversations()

    #expect(listed.map(\.title) == ["Active", "Quiet, renamed"])
  }
}
