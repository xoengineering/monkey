import Foundation
import FoundationModels
import Testing

@testable import MonkeyCore

@Suite struct ModelSessionTests {
  private func makeTemporaryRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ModelSessionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func surfacesUnavailableReasonWithoutSilentFailure() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let backend = FakeChatBackend(availability: .unavailable(.appleIntelligenceNotEnabled))
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    await #expect(throws: ModelSessionError.self) {
      try await session.send("Hello")
    }
  }

  @Test func writesUserMessageThenStreamsAssistantReplyToCompletion() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let backend = FakeChatBackend(results: [.chunks(["Hi", "Hi there", "Hi there!"])])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    let assistantMessage = try await session.send("Hello")

    #expect(assistantMessage.status == .complete)
    #expect(assistantMessage.body == "Hi there!")
    #expect(assistantMessage.role == .assistant)
    #expect(assistantMessage.inReplyTo != nil)

    let index = try await store.messageIndex(for: conversation.id)
    #expect(index.count == 2)

    let messages = try await store.loadMessages(index, in: conversation.id)
    #expect(messages[0].role == .user)
    #expect(messages[0].body == "Hello")
    #expect(messages[1].role == .assistant)
    #expect(messages[1].status == .complete)
  }

  @Test func callsOnUpdateForEachThrottledWriteAndTerminalStates() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let backend = FakeChatBackend(results: [.chunks(["Hi", "Hi there!"])])
    let session = ModelSession(
      backend: backend, store: store, conversation: conversation, streamThrottleInterval: 0)

    let updates = LockedArray<Message>()
    let assistantMessage = try await session.send("Hello") { message in
      updates.append(message)
    }

    let recorded = updates.values
    #expect(recorded.first?.role == .user)
    #expect(recorded.first?.body == "Hello")
    #expect(recorded.dropFirst().map(\.status) == [.streaming, .streaming, .streaming, .complete])
    #expect(recorded.last?.body == assistantMessage.body)
  }

  @Test func replaysStoredHistoryOnNextSend() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let backend = FakeChatBackend(
      results: [.chunks(["First reply"]), .chunks(["Second reply"])])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    _ = try await session.send("First message")
    _ = try await session.send("Second message")

    let secondCall = backend.recordedCalls[1]
    #expect(secondCall.history.map(\.body) == ["First message", "First reply"])
    #expect(secondCall.prompt == "Second message")
  }

  @Test func trimsOldestHistoryToFitContextWindowWhenReplaying() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    for index in 0..<5 {
      let name = TimestampedName(timestamp: Date(timeIntervalSinceNow: Double(index)))
      let message = Message(
        id: MessageID(rawValue: name.key),
        role: index.isMultiple(of: 2) ? .user : .assistant,
        createdAt: name.timestamp,
        status: .complete,
        model: "fake-model",
        body: "message \(index)"
      )
      try await store.write(message, in: conversation.id)
    }

    // contextSize 25, 10 tokens/turn -> only the 2 most recent turns fit.
    let backend = FakeChatBackend(contextSize: 25, tokensPerTurn: 10, results: [.chunks(["ok"])])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    _ = try await session.send("new message")

    let call = try #require(backend.recordedCalls.first)
    #expect(call.history.map(\.body) == ["message 3", "message 4"])
  }

  @Test func marksMessageCancelledWhenTaskIsCancelled() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")
    let backend = FakeChatBackend(results: [.chunks(Array(repeating: "chunk", count: 1000))])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    let task = Task {
      try await session.send("Hello")
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }

    let index = try await store.messageIndex(for: conversation.id)
    let messages = try await store.loadMessages(index, in: conversation.id)
    let assistantMessage = try #require(messages.first { $0.role == .assistant })
    #expect(assistantMessage.status == .cancelled)
  }

  @Test func retriesOnceAfterTrimmingWhenContextSizeExceeded() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    let name = TimestampedName(timestamp: Date(timeIntervalSinceNow: -10))
    let priorMessage = Message(
      id: MessageID(rawValue: name.key),
      role: .user,
      createdAt: name.timestamp,
      status: .complete,
      model: "fake-model",
      body: "earlier message"
    )
    try await store.write(priorMessage, in: conversation.id)

    let overflow = LanguageModelError.contextSizeExceeded(
      .init(contextSize: 100, tokenCount: 200, debugDescription: "too much"))
    let backend = FakeChatBackend(
      results: [.failure(overflow), .chunks(["fits now"])])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    let assistantMessage = try await session.send("new message")

    #expect(assistantMessage.status == .complete)
    #expect(assistantMessage.body == "fits now")
    #expect(backend.recordedCalls.count == 2)
    #expect(backend.recordedCalls[0].history.map(\.body) == ["earlier message"])
    #expect(backend.recordedCalls[0].prompt == "new message")
    #expect(backend.recordedCalls[1].history.isEmpty)
    #expect(backend.recordedCalls[1].prompt == "new message")
  }

  @Test func failsMessageWhenSecondAttemptStillExceedsContext() async throws {
    let root = try makeTemporaryRoot()
    let store = ConversationStore(rootURL: root)
    let conversation = try await store.create(title: "Chat")

    let overflow = LanguageModelError.contextSizeExceeded(
      .init(contextSize: 100, tokenCount: 200, debugDescription: "too much"))
    let backend = FakeChatBackend(results: [.failure(overflow), .failure(overflow)])
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    await #expect(throws: LanguageModelError.self) {
      try await session.send("new message")
    }

    let index = try await store.messageIndex(for: conversation.id)
    let messages = try await store.loadMessages(index, in: conversation.id)
    let assistantMessage = try #require(messages.first { $0.role == .assistant })
    #expect(assistantMessage.status == .failed)
    #expect(assistantMessage.error != nil)
  }
}
