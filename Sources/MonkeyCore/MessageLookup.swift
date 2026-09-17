/// Result of resolving a user-supplied message reference — a file name, any
/// unique prefix, or a negative index (`-1` = last), per PLAN.md §5.
public enum MessageLookup: Sendable {
  case found(MessageFileName)
  case notFound
  case ambiguous([MessageFileName])
}

extension ConversationStore {
  public func resolveMessage(
    matching reference: String, in id: ConversationID
  ) async throws -> MessageLookup {
    let index = try messageIndex(for: id)

    if let negativeOffset = Int(reference), negativeOffset < 0 {
      let position = index.count + negativeOffset
      guard index.indices.contains(position) else { return .notFound }
      return .found(index[position])
    }

    if let exact = index.first(where: { $0.description == reference || $0.id.rawValue == reference }
    ) {
      return .found(exact)
    }

    let matches = index.filter {
      $0.description.hasPrefix(reference) || $0.id.rawValue.hasPrefix(reference)
    }
    switch matches.count {
    case 0: return .notFound
    case 1: return .found(matches[0])
    default: return .ambiguous(matches)
    }
  }
}
