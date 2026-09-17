/// Result of resolving a user-supplied conversation reference (a full folder
/// name or any unique prefix, per PLAN.md §5) against the store.
public enum ConversationLookup: Sendable {
  case found(Conversation)
  case notFound
  case ambiguous([Conversation])
}

extension ConversationStore {
  public func resolveConversation(matching reference: String) async throws -> ConversationLookup {
    let conversations = try listConversations()

    if let exact = conversations.first(where: { $0.id.rawValue == reference }) {
      return .found(exact)
    }

    let matches = conversations.filter { $0.id.rawValue.hasPrefix(reference) }
    switch matches.count {
    case 0: return .notFound
    case 1: return .found(matches[0])
    default: return .ambiguous(matches)
    }
  }
}
