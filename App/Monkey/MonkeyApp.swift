import Foundation
import MonkeyCore
import MonkeyUI
import SwiftUI

#if os(macOS)
  import AppKit
#endif

@main
struct MonkeyApp: App {
  @State private var environment: AppEnvironment
  @AppStorage(GeneralSettings.defaultInstructionsKey) private var defaultInstructions = ""

  init() {
    #if os(macOS)
      // The app has no tabs; this removes View > Show Tab Bar / Show All Tabs
      // and the Window menu's tab items.
      NSWindow.allowsAutomaticWindowTabbing = false
    #endif

    let root = AppGroupStorage.conversationsRootURL()
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = ConversationStore(rootURL: root)
    _environment = State(initialValue: AppEnvironment(store: store, backend: SystemChatBackend()))
  }

  var body: some Scene {
    WindowGroup(id: MonkeyRootView.windowID) {
      MonkeyRootView(environment: environment, defaultInstructions: $defaultInstructions)
    }
    .commands {
      MonkeyCommands()
    }

    #if os(macOS)
      Settings {
        SettingsTabsView(defaultInstructions: $defaultInstructions, environment: environment)
      }
    #endif
  }
}
