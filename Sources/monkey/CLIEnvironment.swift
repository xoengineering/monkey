import Foundation
import MonkeyCore

enum CLIEnvironment {
  /// Reads the same `StorageLocation` the app's Settings picker wrote, per
  /// PLAN.md §5 ("the CLI reads whichever root the app's Settings selected,
  /// via a shared preference in the group container"). Falls back to
  /// on-device if iCloud was selected but its container isn't available —
  /// same fallback `AppEnvironment` uses on the app side.
  static var rootURL: URL {
    let location = StorageLocationPreference.load()
    let root =
      ConversationsRootResolver.resolve(location: location)
      ?? AppGroupStorage.conversationsRootURL()
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  static func makeStore() -> ConversationStore {
    ConversationStore(rootURL: rootURL)
  }

  static func makeBackend() -> any ChatBackend {
    SystemChatBackend()
  }
}
