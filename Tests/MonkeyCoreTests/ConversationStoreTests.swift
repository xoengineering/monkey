import Foundation
import Testing

@testable import MonkeyCore

@Suite struct ConversationStoreTests {
  private func makeTemporaryRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ConversationStoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func createsAConversationDirectoryWithYAML() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)

    let conversation = try await store.create(title: "Weekend trip")

    let yamlURL = root.appendingPathComponent(conversation.id.rawValue)
      .appendingPathComponent("conversation.yaml")
    #expect(FileManager.default.fileExists(atPath: yamlURL.path))
    #expect(conversation.title == "Weekend trip")
    #expect(conversation.messageCount == 0)
  }

  @Test func updateRewritesConversationYAML() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    var conversation = try await store.create(title: "Original")

    conversation.title = "Renamed"
    try await store.update(conversation)

    let reloaded = try await store.listConversations().first
    #expect(reloaded?.title == "Renamed")
  }

  @Test func deleteRemovesTheConversationDirectory() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Doomed")

    try await store.delete(conversation.id)

    let listed = try await store.listConversations()
    #expect(listed.isEmpty)
  }

  @Test func writesAndLoadsAMessage() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let timestampedName = try #require(TimestampedName(parsing: TimestampedName().description))
    let message = Message(
      id: MessageID(rawValue: timestampedName.key),
      role: .user,
      createdAt: timestampedName.timestamp,
      status: .complete,
      model: "system-on-device",
      body: "Hello there."
    )

    try await store.write(message, in: conversation.id)
    let index = try await store.messageIndex(for: conversation.id)
    let loaded = try await store.loadMessage(try #require(index.first), in: conversation.id)

    #expect(index.count == 1)
    #expect(loaded == message)
  }

  @Test func writeRefreshesConversationMessageCountAndUpdatedAt() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let original = try await store.create(title: "Chat")
    let name = TimestampedName()
    let message = Message(
      id: MessageID(rawValue: name.key),
      role: .user,
      createdAt: name.timestamp,
      status: .complete,
      model: "system-on-device",
      body: "Hello there."
    )

    try await store.write(message, in: original.id)

    let refreshed = try #require(try await store.listConversations().first)
    #expect(refreshed.messageCount == 1)
    #expect(refreshed.updatedAt >= original.updatedAt)
    let lastMessageAt = try #require(refreshed.lastMessageAt)
    #expect(
      ISO8601Milliseconds.string(from: lastMessageAt)
        == ISO8601Milliseconds.string(from: message.createdAt))
  }

  @Test func messageIndexIsSortedChronologically() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    let earlier = TimestampedName(
      timestamp: Date(timeIntervalSince1970: 1_800_000_000), key: "aaaaaa")
    let later = TimestampedName(
      timestamp: Date(timeIntervalSince1970: 1_800_000_100), key: "bbbbbb")

    for name in [later, earlier] {
      let message = Message(
        id: MessageID(rawValue: name.key),
        role: .user,
        createdAt: name.timestamp,
        status: .complete,
        model: "system-on-device",
        body: "text"
      )
      try await store.write(message, in: conversation.id)
    }

    let index = try await store.messageIndex(for: conversation.id)

    #expect(index.map(\.id.rawValue) == ["aaaaaa", "bbbbbb"])
  }

  @Test func loadMessagesBatchLoadsInOrder() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    var writtenIDs: [String] = []
    for key in ["aaaaaa", "bbbbbb", "cccccc"] {
      let name = TimestampedName(timestamp: Date(), key: key)
      let message = Message(
        id: MessageID(rawValue: key),
        role: .user,
        createdAt: name.timestamp,
        status: .complete,
        model: "system-on-device",
        body: "text \(key)"
      )
      try await store.write(message, in: conversation.id)
      writtenIDs.append(key)
    }

    let index = try await store.messageIndex(for: conversation.id)
    let messages = try await store.loadMessages(index, in: conversation.id)

    #expect(messages.map(\.id.rawValue) == index.map(\.id.rawValue))
    #expect(Set(messages.map(\.id.rawValue)) == Set(writtenIDs))
  }

  @Test func writeIsAtomicAndLeavesNoTemporaryFiles() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let name = TimestampedName()
    let message = Message(
      id: MessageID(rawValue: name.key),
      role: .user,
      createdAt: name.timestamp,
      status: .complete,
      model: "system-on-device",
      body: "text"
    )

    try await store.write(message, in: conversation.id)

    let directoryURL = root.appendingPathComponent(conversation.id.rawValue)
    let entries = try FileManager.default.contentsOfDirectory(
      at: directoryURL, includingPropertiesForKeys: nil)
    let temporaryFiles = entries.filter { $0.lastPathComponent.contains(".tmp-") }
    #expect(temporaryFiles.isEmpty)
  }

  @Test func loadedMessagesAreCachedAndSurviveFileDeletion() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let name = TimestampedName()
    let message = Message(
      id: MessageID(rawValue: name.key),
      role: .user,
      createdAt: name.timestamp,
      status: .complete,
      model: "system-on-device",
      body: "text"
    )
    try await store.write(message, in: conversation.id)
    let fileName = try #require(try await store.messageIndex(for: conversation.id).first)

    try FileManager.default.removeItem(
      at: root.appendingPathComponent(conversation.id.rawValue)
        .appendingPathComponent(fileName.description))

    let loaded = try await store.loadMessage(fileName, in: conversation.id)
    #expect(loaded == message)
  }

  @Test func externalWriteInvalidatesTheCachedMessage() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    await store.startPresenting()
    let conversation = try await store.create(title: "Chat")
    let name = TimestampedName()
    let original = Message(
      id: MessageID(rawValue: name.key), role: .user, createdAt: name.timestamp, status: .complete,
      model: "system-on-device", body: "original")
    try await store.write(original, in: conversation.id)
    let fileName = MessageFileName(timestampedName: name)
    _ = try await store.loadMessage(fileName, in: conversation.id)  // prime the cache

    var updated = original
    updated.body = "updated externally"
    let fileURL = root.appendingPathComponent(conversation.id.rawValue)
      .appendingPathComponent(fileName.description)
    var coordinatorError: NSError?
    NSFileCoordinator().coordinate(
      writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError
    ) { coordinatedURL in
      try? updated.serialized().write(to: coordinatedURL, options: .atomic)
    }
    #expect(coordinatorError == nil)

    let deadline = Date().addingTimeInterval(2)
    var reloaded = try await store.loadMessage(fileName, in: conversation.id)
    while reloaded.body != "updated externally", Date() < deadline {
      try await Task.sleep(for: .milliseconds(10))
      reloaded = try await store.loadMessage(fileName, in: conversation.id)
    }

    #expect(reloaded.body == "updated externally")
    await store.stopPresenting()
  }

  @Test func cacheEvictsLeastRecentlyUsedMessagesBeyondLimit() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root, cacheLimit: 1)
    let conversation = try await store.create(title: "Chat")

    var fileNames: [MessageFileName] = []
    for key in ["aaaaaa", "bbbbbb"] {
      let name = TimestampedName(timestamp: Date(), key: key)
      let message = Message(
        id: MessageID(rawValue: key),
        role: .user,
        createdAt: name.timestamp,
        status: .complete,
        model: "system-on-device",
        body: "text \(key)"
      )
      try await store.write(message, in: conversation.id)
      fileNames.append(MessageFileName(timestampedName: name))
    }

    let directoryURL = root.appendingPathComponent(conversation.id.rawValue)
    try FileManager.default.removeItem(
      at: directoryURL.appendingPathComponent(fileNames[0].description))

    await #expect(throws: (any Error).self) {
      try await store.loadMessage(fileNames[0], in: conversation.id)
    }
  }
}
