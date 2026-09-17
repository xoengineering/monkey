import ArgumentParser
import Foundation
import MonkeyCore

struct CatCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cat",
    abstract: "Print a message body, or a whole conversation, to stdout.")

  @Argument(help: "Conversation reference: full id or unique prefix.")
  var conversation: String

  @Argument(
    help: ArgumentHelp(
      "Message reference: file name, unique prefix, or negative index (pass -- before a bare"
        + " negative index, e.g. `monkey cat <convo> -- -1`). Omit to print the whole conversation."
    )
  )
  var message: String?

  @Flag(help: "Include YAML frontmatter in the output.")
  var raw = false

  @Flag(name: .long, help: "Print machine-readable JSON instead of markdown.")
  var json = false

  func run() async throws {
    let store = CLIEnvironment.makeStore()
    let resolvedConversation = try await ConversationReferenceResolver.resolve(
      conversation, in: store)

    if let messageReference = message {
      let fileName = try await MessageReferenceResolver.resolve(
        messageReference, in: resolvedConversation.id, store: store)
      let loaded = try await store.loadMessage(fileName, in: resolvedConversation.id)
      try printMessage(loaded)
      return
    }

    let fileNames = try await store.messageIndex(for: resolvedConversation.id)
    let messages = try await store.loadMessages(fileNames, in: resolvedConversation.id)

    if json {
      try CLIOutput.printJSON(messages.map(MessageJSON.init))
    } else if raw {
      for loaded in messages {
        print(String(bytes: try loaded.serialized(), encoding: .utf8) ?? "")
      }
    } else {
      print(messages.map(\.body).joined(separator: "\n\n"))
    }
  }

  private func printMessage(_ message: Message) throws {
    if json {
      try CLIOutput.printJSON(MessageJSON(message))
    } else if raw {
      print(String(bytes: try message.serialized(), encoding: .utf8) ?? "")
    } else {
      print(message.body)
    }
  }
}
