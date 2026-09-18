import ArgumentParser
import Foundation
import MonkeyCore

struct ChatCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "chat", abstract: "Interactive REPL over a conversation.")

  @Argument(help: "Conversation reference to continue. Omit to start a new conversation.")
  var conversation: String?

  func run() async throws {
    let backend = CLIEnvironment.makeBackend()
    guard case .available = backend.availability else {
      if case .unavailable(let reason) = backend.availability {
        printError(reason.plainTextDescription)
      }
      throw ExitCode(2)
    }

    let store = CLIEnvironment.makeStore()
    let resolvedConversation: Conversation
    if let reference = conversation {
      resolvedConversation = try await ConversationReferenceResolver.resolve(
        reference, in: store)
    } else {
      resolvedConversation = try await store.create(title: Conversation.untitledTitle)
    }

    let session = ModelSession(backend: backend, store: store, conversation: resolvedConversation)
    print(
      "Chatting in \(resolvedConversation.id.rawValue). /quit to exit, /id to print the conversation id."
    )

    while true {
      print("> ", terminator: "")
      fflush(stdout)
      guard let line = readLine() else { break }
      let input = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if input.isEmpty { continue }
      if input == "/quit" { break }
      if input == "/id" {
        print(resolvedConversation.id.rawValue)
        continue
      }

      let printer = StreamPrinter()
      do {
        _ = try await session.send(input) { message in
          guard message.role == .assistant else { return }
          printer.printDelta(of: message.body)
        }
        print("")
      } catch {
        printError(String(describing: error))
      }
    }
  }
}
