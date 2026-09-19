import MonkeyCore
import SwiftUI

struct ConversationListView: View {
  var viewModel: ConversationListViewModel
  @Binding var selection: ConversationID?
  @State private var renamingID: ConversationID?
  @State private var renameText = ""
  @State private var pendingDeletion: Conversation?
  @State private var hoveredID: ConversationID?
  @FocusState private var listFocused: Bool
  @FocusState private var renameFieldFocused: Bool

  var body: some View {
    Group {
      if viewModel.conversations.isEmpty {
        ContentUnavailableView(
          "No Conversations", systemImage: "bubble.left.and.bubble.right",
          description: Text("Create a new conversation to get started."))
      } else {
        List(viewModel.conversations, selection: $selection) { conversation in
          row(for: conversation)
        }
        .focused($listFocused)
        // Return and ⌘⌫ arrive as File-menu key equivalents, not key presses
        // on the list, because `.onKeyPress`/`.onDeleteCommand` on a `List`
        // never fired here even with the list focused.
        .focusedValue(\.selectedConversationActions, selectedConversationActions)
      }
    }
    .task { await viewModel.refresh() }
    .alert(
      "Delete “\(pendingDeletion?.title ?? "")”?", isPresented: deleteBinding,
      presenting: pendingDeletion
    ) { conversation in
      Button("Delete", role: .destructive) {
        Task { await viewModel.delete(conversation) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("Its messages are deleted from disk. This can’t be undone.")
    }
    .alert(
      "Something Went Wrong",
      isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.errorMessage = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  @ViewBuilder
  private func row(for conversation: Conversation) -> some View {
    HStack {
      VStack(alignment: .leading) {
        titleView(for: conversation)
          // Same height whether it's the Text or the rename TextField, so
          // entering rename mode doesn't grow the row and shift its neighbors.
          .frame(height: titleHeight, alignment: .leading)
        Text("\(conversation.messageCount) messages")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 2)
      Spacer(minLength: 0)
      #if os(macOS)
        if hoveredID == conversation.id, renamingID != conversation.id {
          Button("Delete", systemImage: "xmark.circle.fill") {
            pendingDeletion = conversation
          }
          .buttonStyle(.plain)
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
        }
      #endif
    }
    .contentShape(Rectangle())
    // Clicking a row doesn't move keyboard focus off the composer on its own,
    // so selection is handled here: select the row and keep focus in the
    // list (blue selection), so ↑/↓ move, Return renames, and ⌘⌫ deletes.
    // Only a brand-new conversation sends focus to the composer.
    .onTapGesture {
      guard renamingID != conversation.id else { return }
      selection = conversation.id
      listFocused = true
    }
    .onHover { isHovering in
      if isHovering {
        hoveredID = conversation.id
      } else if hoveredID == conversation.id {
        hoveredID = nil
      }
    }
    .contextMenu {
      Button("Rename", systemImage: "pencil") { beginRename(conversation) }
      Button("Delete", systemImage: "trash", role: .destructive) {
        pendingDeletion = conversation
      }
    }
    #if os(iOS)
      .swipeActions(edge: .trailing) {
        Button("Delete", systemImage: "trash", role: .destructive) {
          pendingDeletion = conversation
        }
      }
    #endif
  }

  @ViewBuilder
  private func titleView(for conversation: Conversation) -> some View {
    if renamingID == conversation.id {
      TextField("Title", text: $renameText)
        .textFieldStyle(.plain)
        .focused($renameFieldFocused)
        // Focus has to be requested once the field exists; setting the
        // FocusState before it's in the hierarchy is silently dropped.
        .onAppear { renameFieldFocused = true }
        .onKeyPress(.return) {
          commitRename(conversation)
          return .handled
        }
        .onKeyPress(.escape) {
          cancelRename()
          return .handled
        }
    } else {
      Text(conversation.title)
    }
  }

  /// Tall enough for a plain-style body TextField (measured 3pt taller than
  /// the Text it replaces).
  private let titleHeight: CGFloat = 22

  private var selectedConversation: Conversation? {
    viewModel.conversations.first { $0.id == selection }
  }

  private var selectedConversationActions: SelectedConversationActions? {
    guard let selected = selectedConversation else { return nil }
    return SelectedConversationActions(
      delete: { pendingDeletion = selected },
      // The rename field lives inside the focused list, so a bare Return
      // reaches this command before the field's own key handler.
      rename: { renamingID == selected.id ? commitRename(selected) : beginRename(selected) }
    )
  }

  private var deleteBinding: Binding<Bool> {
    Binding(
      get: { pendingDeletion != nil },
      set: { if !$0 { pendingDeletion = nil } }
    )
  }

  private func beginRename(_ conversation: Conversation) {
    renameText = conversation.title
    renamingID = conversation.id
    renameFieldFocused = true
  }

  private func commitRename(_ conversation: Conversation) {
    let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    renamingID = nil
    listFocused = true
    guard !title.isEmpty, title != conversation.title else { return }
    Task { await viewModel.rename(conversation, to: title) }
  }

  private func cancelRename() {
    renamingID = nil
    listFocused = true
  }
}
