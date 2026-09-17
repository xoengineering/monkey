import Foundation
import MonkeyCore
import MonkeyUI
import SwiftUI

@main
struct MonkeyApp: App {
  @State private var environment: AppEnvironment
  @State private var defaultInstructions = ""

  init() {
    let root = AppGroupStorage.conversationsRootURL()
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = ConversationStore(rootURL: root)
    _environment = State(initialValue: AppEnvironment(store: store, backend: SystemChatBackend()))
  }

  var body: some Scene {
    WindowGroup {
      MonkeyRootView(environment: environment, defaultInstructions: $defaultInstructions)
    }

    #if os(macOS)
      Settings {
        SettingsTabsView(defaultInstructions: $defaultInstructions, environment: environment)
      }
    #endif
  }
}
