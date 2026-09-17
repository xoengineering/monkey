import AppKit
import ArgumentParser
import MonkeyCore

/// The only file in this target that imports AppKit: revealing a folder in
/// Finder has no SwiftUI equivalent, and this CLI target has no SwiftUI
/// surface to leak into (see PLAN.md §1's "wrap, don't leak" rule).
struct OpenCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "open",
    abstract: "Reveal the conversations root, or one conversation folder, in Finder.")

  @Argument(
    help:
      "Conversation reference: full id or unique prefix. Omit to reveal the conversations root."
  )
  var conversation: String?

  func run() async throws {
    guard let reference = conversation else {
      NSWorkspace.shared.activateFileViewerSelecting([CLIEnvironment.rootURL])
      return
    }

    let store = CLIEnvironment.makeStore()
    let resolved = try await ConversationReferenceResolver.resolve(reference, in: store)
    let folderURL = CLIEnvironment.rootURL.appendingPathComponent(
      resolved.id.rawValue, isDirectory: true)
    NSWorkspace.shared.activateFileViewerSelecting([folderURL])
  }
}
