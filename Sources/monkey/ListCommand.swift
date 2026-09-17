import ArgumentParser
import MonkeyCore

struct ListCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ls", abstract: "List conversations, newest first.")

  @Flag(name: .long, help: "Print machine-readable JSON instead of a table.")
  var json = false

  func run() async throws {
    let store = CLIEnvironment.makeStore()
    let conversations = try await store.listConversations()

    if json {
      try CLIOutput.printJSON(conversations.map(ConversationJSON.init))
      return
    }

    guard !conversations.isEmpty else {
      print("No conversations yet.")
      return
    }

    for conversation in conversations {
      let updatedAt = ISO8601Milliseconds.string(from: conversation.updatedAt)
      let summary =
        "\(conversation.id.rawValue)  \(conversation.title)"
        + "  \(conversation.messageCount) messages  updated \(updatedAt)"
      print(summary)
    }
  }
}

private struct ConversationJSON: Encodable {
  let id: String
  let title: String
  let messageCount: Int
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id, title
    case messageCount = "message_count"
    case updatedAt = "updated_at"
  }

  init(_ conversation: Conversation) {
    id = conversation.id.rawValue
    title = conversation.title
    messageCount = conversation.messageCount
    updatedAt = ISO8601Milliseconds.string(from: conversation.updatedAt)
  }
}
