import Foundation
import FoundationModels

public enum ModelSessionError: Error, Equatable {
  case unavailable(SystemLanguageModel.Availability)
}

/// Owns one conversation's chat turn: rebuilding replay history from stored
/// messages (trimmed to the model's context window), streaming a new response
/// into the store at a throttled cadence, and handling cancellation and
/// context-window overflow.
public actor ModelSession {
  private let backend: any ChatBackend
  private let store: ConversationStore
  private let conversation: Conversation
  private let streamThrottleInterval: TimeInterval

  private var history: [ChatTurn] = []
  private var isHistoryLoaded = false

  public init(
    backend: any ChatBackend,
    store: ConversationStore,
    conversation: Conversation,
    streamThrottleInterval: TimeInterval = 0.25
  ) {
    self.backend = backend
    self.store = store
    self.conversation = conversation
    self.streamThrottleInterval = streamThrottleInterval
  }

  public var availability: SystemLanguageModel.Availability {
    backend.availability
  }

  /// Rebuilds replay history from the store, trimming the oldest messages
  /// until what's left fits the model's context window.
  public func loadHistoryIfNeeded() async throws {
    guard !isHistoryLoaded else { return }

    let fileNames = try await store.messageIndex(for: conversation.id)
    let messages = try await store.loadMessages(fileNames, in: conversation.id)
    var turns = messages.map { ChatTurn(role: $0.role, body: $0.body) }

    while !turns.isEmpty {
      let count = try await backend.tokenCount(
        for: turns, instructions: conversation.instructions)
      if count <= backend.contextSize {
        break
      }
      turns.removeFirst()
    }

    history = turns
    isHistoryLoaded = true
  }

  @discardableResult
  public func send(_ body: String) async throws -> Message {
    guard case .available = backend.availability else {
      throw ModelSessionError.unavailable(backend.availability)
    }

    try await loadHistoryIfNeeded()

    let userName = TimestampedName()
    let userMessage = Message(
      id: MessageID(rawValue: userName.key),
      role: .user,
      createdAt: userName.timestamp,
      status: .complete,
      model: backend.identifier,
      body: body
    )
    try await store.write(userMessage, in: conversation.id)

    let assistantName = TimestampedName()
    let assistantMessage = Message(
      id: MessageID(rawValue: assistantName.key),
      role: .assistant,
      createdAt: assistantName.timestamp,
      status: .streaming,
      model: backend.identifier,
      inReplyTo: userMessage.id,
      body: ""
    )
    try await store.write(assistantMessage, in: conversation.id)

    var replayHistory = history

    do {
      let finished = try await stream(
        assistantMessage, history: &replayHistory, prompt: body, allowTrimRetry: true)
      let userTurn = ChatTurn(role: .user, body: body)
      let assistantTurn = ChatTurn(role: .assistant, body: finished.body)
      history = replayHistory + [userTurn, assistantTurn]
      return finished
    } catch is CancellationError {
      var cancelled = assistantMessage
      cancelled.status = .cancelled
      try await store.write(cancelled, in: conversation.id)
      history = replayHistory + [ChatTurn(role: .user, body: body)]
      throw CancellationError()
    } catch {
      var failed = assistantMessage
      failed.status = .failed
      failed.error = String(describing: error)
      try await store.write(failed, in: conversation.id)
      history = replayHistory + [ChatTurn(role: .user, body: body)]
      throw error
    }
  }

  private func stream(
    _ initialMessage: Message,
    history: inout [ChatTurn],
    prompt: String,
    allowTrimRetry: Bool
  ) async throws -> Message {
    var message = initialMessage
    message.body = ""
    var lastWrite = Date.distantPast

    do {
      let stream = backend.streamResponse(
        history: history, instructions: conversation.instructions, prompt: prompt)
      for try await chunk in stream {
        try Task.checkCancellation()
        message.body = chunk
        if Date().timeIntervalSince(lastWrite) >= streamThrottleInterval {
          try await store.write(message, in: conversation.id)
          lastWrite = Date()
        }
      }
    } catch let error as LanguageModelError {
      if case .contextSizeExceeded = error, allowTrimRetry, !history.isEmpty {
        history.removeFirst()
        return try await stream(
          initialMessage, history: &history, prompt: prompt, allowTrimRetry: false)
      }
      throw error
    }

    message.status = .complete
    try await store.write(message, in: conversation.id)
    return message
  }
}
