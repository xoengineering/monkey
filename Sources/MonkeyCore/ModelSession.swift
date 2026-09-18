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
  public private(set) var conversation: Conversation
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

  /// - Parameter onUpdate: called on the store's throttled cadence (and once
  ///   more for the user message and every terminal state) so a UI observer
  ///   can mirror progress without polling the store.
  @discardableResult
  public func send(
    _ body: String, onUpdate: (@Sendable (Message) -> Void)? = nil
  ) async throws -> Message {
    guard case .available = backend.availability else {
      throw ModelSessionError.unavailable(backend.availability)
    }

    try await loadHistoryIfNeeded()

    // A conversation stops being "Untitled" the moment it has content.
    let isFirstMessage = try await store.messageIndex(for: conversation.id).isEmpty
    if isFirstMessage, conversation.title == Conversation.untitledTitle {
      conversation.title = ConversationTitle.derive(from: body)
      conversation.updatedAt = Date()
      try await store.update(conversation)
    }

    let userMessage = makeMessage(role: .user, status: .complete, body: body)
    try await store.write(userMessage, in: conversation.id)
    onUpdate?(userMessage)

    let assistantMessage = makeMessage(
      role: .assistant, status: .streaming, body: "", inReplyTo: userMessage.id)
    try await store.write(assistantMessage, in: conversation.id)
    onUpdate?(assistantMessage)

    var replayHistory = history

    do {
      let finished = try await stream(
        assistantMessage, history: &replayHistory, prompt: body, allowTrimRetry: true,
        onUpdate: onUpdate)
      let userTurn = ChatTurn(role: .user, body: body)
      let assistantTurn = ChatTurn(role: .assistant, body: finished.body)
      history = replayHistory + [userTurn, assistantTurn]
      return finished
    } catch is CancellationError {
      var cancelled = assistantMessage
      cancelled.status = .cancelled
      try await store.write(cancelled, in: conversation.id)
      onUpdate?(cancelled)
      history = replayHistory + [ChatTurn(role: .user, body: body)]
      throw CancellationError()
    } catch {
      var failed = assistantMessage
      failed.status = .failed
      failed.error = String(describing: error)
      try await store.write(failed, in: conversation.id)
      onUpdate?(failed)
      history = replayHistory + [ChatTurn(role: .user, body: body)]
      throw error
    }
  }

  private func makeMessage(
    role: MessageRole, status: MessageStatus, body: String, inReplyTo: MessageID? = nil
  ) -> Message {
    let name = TimestampedName()
    return Message(
      id: MessageID(rawValue: name.key),
      role: role,
      createdAt: name.timestamp,
      status: status,
      model: backend.identifier,
      inReplyTo: inReplyTo,
      body: body
    )
  }

  private func stream(
    _ initialMessage: Message,
    history: inout [ChatTurn],
    prompt: String,
    allowTrimRetry: Bool,
    onUpdate: (@Sendable (Message) -> Void)?
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
          onUpdate?(message)
          lastWrite = Date()
        }
      }
    } catch let error as LanguageModelError {
      if case .contextSizeExceeded = error, allowTrimRetry, !history.isEmpty {
        history.removeFirst()
        return try await stream(
          initialMessage, history: &history, prompt: prompt, allowTrimRetry: false,
          onUpdate: onUpdate)
      }
      throw error
    }

    message.status = .complete
    try await store.write(message, in: conversation.id)
    onUpdate?(message)
    return message
  }
}
