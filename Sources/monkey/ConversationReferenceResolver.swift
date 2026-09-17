import ArgumentParser
import MonkeyCore

enum ConversationReferenceResolver {
  static func resolve(
    _ reference: String, in store: ConversationStore
  ) async throws -> Conversation {
    switch try await store.resolveConversation(matching: reference) {
    case .found(let conversation):
      return conversation
    case .notFound:
      printError("No conversation matches \"\(reference)\".")
      throw ExitCode(1)
    case .ambiguous(let matches):
      printError("\"\(reference)\" matches multiple conversations:")
      for match in matches {
        printError("  \(match.id.rawValue)  \(match.title)")
      }
      throw ExitCode(1)
    }
  }
}
