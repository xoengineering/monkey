import MonkeyCore
import SwiftUI

struct ConversationListView: View {
  var viewModel: ConversationListViewModel
  @Binding var selection: ConversationID?
  @State private var renamingConversation: Conversation?
  @State private var renameText = ""

  var body: some View {
    Group {
      if viewModel.conversations.isEmpty {
        ContentUnavailableView(
          "No Conversations", systemImage: "bubble.left.and.bubble.right",
          description: Text("Create a new conversation to get started."))
      } else {
        List(viewModel.conversations, selection: $selection) { conversation in
          NavigationLink(value: conversation.id) {
            VStack(alignment: .leading) {
              Text(conversation.title)
              Text("\(conversation.messageCount) messages")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .contextMenu {
            Button("Rename") {
              renamingConversation = conversation
              renameText = conversation.title
            }
            Button("Delete", role: .destructive) {
              Task { await viewModel.delete(conversation) }
            }
          }
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Conversation", systemImage: "square.and.pencil") {
          Task {
            if let conversation = await viewModel.createConversation() {
              selection = conversation.id
            }
          }
        }
        .keyboardShortcut("n", modifiers: .command)
      }
    }
    .task { await viewModel.refresh() }
    .alert(
      "Rename Conversation", isPresented: renameBinding,
      presenting: renamingConversation
    ) { conversation in
      TextField("Title", text: $renameText)
      Button("Cancel", role: .cancel) {}
      Button("Rename") {
        Task { await viewModel.rename(conversation, to: renameText) }
      }
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

  private var renameBinding: Binding<Bool> {
    Binding(
      get: { renamingConversation != nil },
      set: { if !$0 { renamingConversation = nil } }
    )
  }
}
