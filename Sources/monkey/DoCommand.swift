import ArgumentParser
import Foundation
import MonkeyCore

struct DoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "do", abstract: "Send a one-shot prompt and stream the reply to stdout.")

  @Argument(help: "The prompt. Reads from stdin too if it's piped in.")
  var prompt: [String] = []

  @Flag(help: "Don't write anything to disk.")
  var ephemeral = false

  func run() async throws {
    let backend = CLIEnvironment.makeBackend()
    guard case .available = backend.availability else {
      if case .unavailable(let reason) = backend.availability {
        printError(reason.plainTextDescription)
      }
      throw ExitCode(2)
    }

    let text = StandardInput.appendingPipedInput(to: prompt.joined(separator: " "))
    guard !text.isEmpty else {
      printError("Usage: monkey do <prompt…>")
      throw ExitCode(1)
    }

    if ephemeral {
      let printer = StreamPrinter()
      for try await chunk in backend.streamResponse(history: [], instructions: nil, prompt: text) {
        printer.printDelta(of: chunk)
      }
      print("")
      return
    }

    let store = CLIEnvironment.makeStore()
    let title = String(text.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
    let conversation = try await store.create(title: title)
    let session = ModelSession(backend: backend, store: store, conversation: conversation)

    let printer = StreamPrinter()
    _ = try await session.send(text) { message in
      guard message.role == .assistant else { return }
      printer.printDelta(of: message.body)
    }
    print("")
  }
}
