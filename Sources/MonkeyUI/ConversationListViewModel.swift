import Foundation
import MonkeyCore
import Observation

@MainActor
@Observable
public final class ConversationListViewModel {
  public private(set) var conversations: [Conversation] = []
  public var errorMessage: String?

  private let store: ConversationStore

  public init(store: ConversationStore) {
    self.store = store
  }

  public func refresh() async {
    do {
      conversations = try await store.listConversations()
    } catch {
      errorMessage = String(describing: error)
    }
  }

  @discardableResult
  public func createConversation() async -> Conversation? {
    do {
      let conversation = try await store.create(title: Conversation.untitledTitle)
      await refresh()
      return conversation
    } catch {
      errorMessage = String(describing: error)
      return nil
    }
  }

  public func delete(_ conversation: Conversation) async {
    do {
      try await store.delete(conversation.id)
      await refresh()
    } catch {
      errorMessage = String(describing: error)
    }
  }

  public func rename(_ conversation: Conversation, to title: String) async {
    var updated = conversation
    updated.title = title
    updated.updatedAt = Date()
    do {
      try await store.update(updated)
      await refresh()
    } catch {
      errorMessage = String(describing: error)
    }
  }
}
