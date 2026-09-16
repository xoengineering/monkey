import Foundation
import FoundationModels
import MonkeyCore
import Observation

@MainActor
@Observable
public final class ConversationDetailViewModel {
  public let conversation: Conversation
  public private(set) var messages: [Message] = []
  public private(set) var canLoadOlderMessages = true
  public private(set) var isLoadingOlder = false
  public private(set) var isSending = false
  public private(set) var availability: SystemLanguageModel.Availability = .unavailable(
    .modelNotReady)
  public var composerText = ""
  public var errorMessage: String?

  private let store: ConversationStore
  private let modelSession: ModelSession
  private let pageSize: Int
  private var fullIndex: [MessageFileName] = []
  private var oldestLoadedIndex = 0
  private var sendTask: Task<Void, Never>?

  public init(
    conversation: Conversation,
    store: ConversationStore,
    backend: any ChatBackend,
    pageSize: Int = 50
  ) {
    self.conversation = conversation
    self.store = store
    self.modelSession = ModelSession(
      backend: backend, store: store, conversation: conversation)
    self.pageSize = pageSize
  }

  public func load() async {
    availability = await modelSession.availability

    do {
      fullIndex = try await store.messageIndex(for: conversation.id)
    } catch {
      errorMessage = String(describing: error)
      return
    }

    oldestLoadedIndex = max(0, fullIndex.count - pageSize)
    canLoadOlderMessages = oldestLoadedIndex > 0

    do {
      messages = try await store.loadMessages(
        Array(fullIndex[oldestLoadedIndex...]), in: conversation.id)
    } catch {
      errorMessage = String(describing: error)
    }
  }

  public func loadOlderMessagesIfNeeded() async {
    guard canLoadOlderMessages, !isLoadingOlder else { return }
    isLoadingOlder = true
    defer { isLoadingOlder = false }

    let newOldestIndex = max(0, oldestLoadedIndex - pageSize)
    let range = newOldestIndex..<oldestLoadedIndex
    guard !range.isEmpty else {
      canLoadOlderMessages = false
      return
    }

    do {
      let older = try await store.loadMessages(Array(fullIndex[range]), in: conversation.id)
      messages = older + messages
      oldestLoadedIndex = newOldestIndex
      canLoadOlderMessages = oldestLoadedIndex > 0
    } catch {
      errorMessage = String(describing: error)
    }
  }

  public func send() {
    let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !isSending else { return }
    composerText = ""
    isSending = true

    sendTask = Task { [weak self] in
      guard let self else { return }
      defer {
        isSending = false
        sendTask = nil
      }
      do {
        _ = try await modelSession.send(text) { [weak self] message in
          Task { @MainActor [weak self] in
            self?.applyLiveUpdate(message)
          }
        }
      } catch is CancellationError {
        // Terminal state already delivered via the onUpdate callback.
      } catch {
        errorMessage = String(describing: error)
      }
      await refreshIndex()
    }
  }

  public func stopSending() {
    sendTask?.cancel()
  }

  private func applyLiveUpdate(_ message: Message) {
    if let index = messages.firstIndex(where: { $0.id == message.id }) {
      messages[index] = message
    } else {
      messages.append(message)
    }
  }

  private func refreshIndex() async {
    do {
      fullIndex = try await store.messageIndex(for: conversation.id)
    } catch {
      errorMessage = String(describing: error)
    }
  }
}
