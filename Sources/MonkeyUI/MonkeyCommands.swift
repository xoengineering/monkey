import SwiftUI

/// App-menu commands. Replaces the default File > New Window (which SwiftUI
/// puts on ⌘N) so ⌘N means "New Conversation" and New Window moves to ⇧⌘N.
public struct MonkeyCommands: Commands {
  @FocusedValue(\.conversationActions) private var conversationActions
  @FocusedValue(\.selectedConversationActions) private var selectedConversationActions
  @Environment(\.openWindow) private var openWindow

  public init() {}

  public var body: some Commands {
    // One group: a separate `CommandGroup(after: .newItem)` alongside this
    // replacement rendered as a bare separator with its buttons dropped.
    CommandGroup(replacing: .newItem) {
      Button("New Conversation", systemImage: "square.and.pencil") {
        conversationActions?.newConversation()
      }
      .keyboardShortcut("n", modifiers: .command)
      .disabled(conversationActions == nil)
      .labelStyle(.titleAndIcon)

      #if os(macOS)
        Button("New Window", systemImage: "macwindow.badge.plus") {
          openWindow(id: MonkeyRootView.windowID)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .labelStyle(.titleAndIcon)
      #endif

      Divider()

      Button("Rename Conversation", systemImage: "pencil") {
        selectedConversationActions?.rename()
      }
      .keyboardShortcut(.return, modifiers: [])
      .disabled(selectedConversationActions == nil)
      .labelStyle(.titleAndIcon)

      Button("Delete Conversation…", systemImage: "trash") {
        selectedConversationActions?.delete()
      }
      .keyboardShortcut(.delete, modifiers: .command)
      .disabled(selectedConversationActions == nil)
      .labelStyle(.titleAndIcon)
    }

    #if os(macOS)
      SidebarCommands()
    #endif
  }
}
