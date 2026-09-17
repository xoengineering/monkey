import ArgumentParser
import MonkeyCore

enum MessageReferenceResolver {
  static func resolve(
    _ reference: String, in conversationID: ConversationID, store: ConversationStore
  ) async throws -> MessageFileName {
    switch try await store.resolveMessage(matching: reference, in: conversationID) {
    case .found(let fileName):
      return fileName
    case .notFound:
      printError("No message matches \"\(reference)\".")
      throw ExitCode(1)
    case .ambiguous(let matches):
      printError("\"\(reference)\" matches multiple messages:")
      for match in matches {
        printError("  \(match.description)")
      }
      throw ExitCode(1)
    }
  }
}
