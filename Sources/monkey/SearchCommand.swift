import ArgumentParser
import MonkeyCore

struct SearchCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "search", abstract: "Search conversation titles and message bodies.")

  @Argument(help: "Substring (or regular expression with --regex) to search for.")
  var query: String

  @Option(name: .customLong("in"), help: "Restrict the search to one conversation.")
  var inConversation: String?

  @Flag(help: "Treat the query as a regular expression instead of a plain substring.")
  var regex = false

  @Flag(name: .long, help: "Print machine-readable JSON instead of a table.")
  var json = false

  func run() async throws {
    let store = CLIEnvironment.makeStore()
    let conversations: [Conversation]
    if let inConversation {
      conversations = [try await ConversationReferenceResolver.resolve(inConversation, in: store)]
    } else {
      conversations = try await store.listConversations()
    }

    let matcher = try Matcher(query: query, useRegex: regex)
    var hits: [SearchHit] = []

    for conversation in conversations {
      if matcher.matches(conversation.title) {
        hits.append(
          SearchHit(
            conversation: conversation.id.rawValue, message: "title", line: 0,
            text: conversation.title))
      }

      let fileNames = try await store.messageIndex(for: conversation.id)
      let messages = try await store.loadMessages(fileNames, in: conversation.id)
      for (fileName, message) in zip(fileNames, messages) {
        let lines = message.body.components(separatedBy: .newlines)
        for (lineIndex, line) in lines.enumerated() where matcher.matches(line) {
          hits.append(
            SearchHit(
              conversation: conversation.id.rawValue, message: fileName.description,
              line: lineIndex + 1, text: line))
        }
      }
    }

    if json {
      try CLIOutput.printJSON(hits)
    } else if hits.isEmpty {
      print("No matches.")
    } else {
      for hit in hits {
        print("\(hit.conversation)  \(hit.message)  \(hit.line)  \(hit.text)")
      }
    }
  }
}

private struct SearchHit: Encodable {
  let conversation: String
  let message: String
  let line: Int
  let text: String
}

struct Matcher {
  private let regex: Regex<AnyRegexOutput>?
  private let substring: String?

  init(query: String, useRegex: Bool) throws {
    if useRegex {
      regex = try Regex("(?i)" + query)
      substring = nil
    } else {
      regex = nil
      substring = query.lowercased()
    }
  }

  func matches(_ text: String) -> Bool {
    if let regex {
      return text.firstMatch(of: regex) != nil
    }
    return text.lowercased().contains(substring ?? "")
  }
}
