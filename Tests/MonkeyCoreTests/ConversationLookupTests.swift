import Foundation
import Testing

@testable import MonkeyCore

@Suite struct ConversationLookupTests {
  private func makeTemporaryRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ConversationLookupTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func resolvesByExactID() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    let result = try await store.resolveConversation(matching: conversation.id.rawValue)

    guard case .found(let found) = result else {
      Issue.record("expected .found, got \(result)")
      return
    }
    #expect(found.id == conversation.id)
  }

  @Test func resolvesByUniquePrefix() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let prefix = String(conversation.id.rawValue.prefix(10))

    let result = try await store.resolveConversation(matching: prefix)

    guard case .found(let found) = result else {
      Issue.record("expected .found, got \(result)")
      return
    }
    #expect(found.id == conversation.id)
  }

  @Test func returnsNotFoundForUnknownReference() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    _ = try await store.create(title: "Chat")

    let result = try await store.resolveConversation(matching: "nope")

    #expect(result == .notFound)
  }

  @Test func returnsAmbiguousForSharedPrefix() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let name1 = TimestampedName(
      timestamp: Date(timeIntervalSince1970: 1_800_000_000), key: "aaaaaa")
    let name2 = TimestampedName(
      timestamp: Date(timeIntervalSince1970: 1_800_000_000), key: "aaaaab")
    for name in [name1, name2] {
      let conversation = Conversation(
        id: ConversationID(timestampedName: name), title: "Chat", createdAt: name.timestamp,
        updatedAt: name.timestamp)
      try FileManager.default.createDirectory(
        at: root.appendingPathComponent(conversation.id.rawValue),
        withIntermediateDirectories: true)
      try await store.update(conversation)
    }
    let sharedPrefix = String(name1.description.prefix(23))

    let result = try await store.resolveConversation(matching: sharedPrefix)

    guard case .ambiguous(let matches) = result else {
      Issue.record("expected .ambiguous, got \(result)")
      return
    }
    #expect(matches.count == 2)
  }
}

extension ConversationLookup: Equatable {
  public static func == (lhs: ConversationLookup, rhs: ConversationLookup) -> Bool {
    switch (lhs, rhs) {
    case (.notFound, .notFound): true
    case (.found(let lhsConversation), .found(let rhsConversation)):
      lhsConversation.id == rhsConversation.id
    case (.ambiguous(let lhsMatches), .ambiguous(let rhsMatches)):
      lhsMatches.map(\.id) == rhsMatches.map(\.id)
    default: false
    }
  }
}
