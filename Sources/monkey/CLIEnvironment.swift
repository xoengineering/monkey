import Foundation
import MonkeyCore

enum CLIEnvironment {
  static var rootURL: URL {
    let root = AppGroupStorage.conversationsRootURL()
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
