import SwiftUI

/// Per-window actions the app-menu commands act on. `MonkeyRootView`
/// publishes one via `.focusedSceneValue`, so ⌘N reaches the key window's
/// own list and selection rather than some global — two windows open means
/// two independent selections, and the command targets whichever is in front.
public struct ConversationActions {
  public var newConversation: () -> Void
}

/// Actions on the sidebar's selected conversation. Published with
/// `.focusedValue` on the list itself (not the scene), so they exist only
/// while the list has keyboard focus: Return renames a selected row but still
/// inserts a newline in the composer, and ⌘⌫ never deletes a conversation
/// while you're typing a message.
public struct SelectedConversationActions {
  public var delete: () -> Void
  public var rename: () -> Void
}

extension FocusedValues {
  @Entry public var conversationActions: ConversationActions?
  @Entry public var selectedConversationActions: SelectedConversationActions?
}
