import Foundation
import MonkeyCore
import MonkeyUI
import SwiftUI

@main
struct MonkeyApp: App {
  private let store: ConversationStore

  init() {
    let root = AppGroupStorage.conversationsRootURL()
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    store = ConversationStore(rootURL: root)
  }

  var body: some Scene {
    WindowGroup {
      MonkeyRootView(store: store, backend: SystemChatBackend())
    }
  }
}
