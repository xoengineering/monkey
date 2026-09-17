import Foundation
import Testing

@testable import MonkeyCore

@Suite struct MessageLookupTests {
  private func makeTemporaryRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("MessageLookupTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func writeMessages(
    _ keys: [String], to store: ConversationStore, in id: ConversationID
  ) async throws {
    for (offset, key) in keys.enumerated() {
      let name = TimestampedName(
        timestamp: Date(timeIntervalSince1970: 1_800_000_000 + Double(offset)), key: key)
      let message = Message(
        id: MessageID(rawValue: key), role: .user, createdAt: name.timestamp, status: .complete,
        model: "system-on-device", body: "text \(key)")
      try await store.write(message, in: id)
    }
  }

  @Test func resolvesByExactFileName() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    try await writeMessages(["aaaaaa", "bbbbbb"], to: store, in: conversation.id)
    let index = try await store.messageIndex(for: conversation.id)

    let result = try await store.resolveMessage(
      matching: index[0].description, in: conversation.id)

    guard case .found(let found) = result else {
      Issue.record("expected .found, got \(result)")
      return
    }
    #expect(found == index[0])
  }

  @Test func resolvesByLastNegativeIndex() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    try await writeMessages(["aaaaaa", "bbbbbb", "cccccc"], to: store, in: conversation.id)
    let index = try await store.messageIndex(for: conversation.id)

    let result = try await store.resolveMessage(matching: "-1", in: conversation.id)

    guard case .found(let found) = result else {
      Issue.record("expected .found, got \(result)")
      return
    }
    #expect(found == index.last)
  }

  @Test func resolvesByUniqueIDPrefix() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    try await writeMessages(["aaaaaa", "bbbbbb"], to: store, in: conversation.id)

    let result = try await store.resolveMessage(matching: "aaa", in: conversation.id)

    guard case .found(let found) = result else {
      Issue.record("expected .found, got \(result)")
      return
    }
    #expect(found.id.rawValue == "aaaaaa")
  }

  @Test func returnsNotFoundForOutOfRangeNegativeIndex() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    try await writeMessages(["aaaaaa"], to: store, in: conversation.id)

    let result = try await store.resolveMessage(matching: "-5", in: conversation.id)

    #expect(result == .notFound)
  }

  @Test func returnsAmbiguousForSharedIDPrefix() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    try await writeMessages(["aaaaaa", "aaaabb"], to: store, in: conversation.id)

    let result = try await store.resolveMessage(matching: "aaaa", in: conversation.id)

    guard case .ambiguous(let matches) = result else {
      Issue.record("expected .ambiguous, got \(result)")
      return
    }
    #expect(matches.count == 2)
  }
}

extension MessageLookup: Equatable {
  public static func == (lhs: MessageLookup, rhs: MessageLookup) -> Bool {
    switch (lhs, rhs) {
    case (.notFound, .notFound): true
    case (.found(let lhsFileName), .found(let rhsFileName)): lhsFileName == rhsFileName
    case (.ambiguous(let lhsMatches), .ambiguous(let rhsMatches)): lhsMatches == rhsMatches
    default: false
    }
  }
}
