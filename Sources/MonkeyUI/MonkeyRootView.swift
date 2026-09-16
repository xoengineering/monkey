import MonkeyCore
import SwiftUI
import Textual

public struct MonkeyRootView: View {
  @State private var listViewModel: ConversationListViewModel
  @State private var selection: ConversationID?
  @State private var showingSettings = false
  @State private var defaultInstructions = ""

  private let store: ConversationStore
  private let backend: any ChatBackend

  public init(store: ConversationStore, backend: any ChatBackend) {
    self.store = store
    self.backend = backend
    _listViewModel = State(initialValue: ConversationListViewModel(store: store))
  }

  public var body: some View {
    NavigationSplitView {
      ConversationListView(viewModel: listViewModel, selection: $selection)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button("Settings", systemImage: "gearshape") {
              showingSettings = true
            }
          }
        }
    } detail: {
      let selectedConversation = listViewModel.conversations.first { $0.id == selection }
      if let conversation = selectedConversation {
        ConversationDetailView(conversation: conversation, store: store, backend: backend)
          .id(conversation.id)
      } else {
        ContentUnavailableView(
          "No Conversation Selected", systemImage: "bubble.left.and.bubble.right")
      }
    }
    .textual.imageAttachmentLoader(NoFetchImageAttachmentLoader())
    .sheet(isPresented: $showingSettings) {
      SettingsView(defaultInstructions: $defaultInstructions)
    }
  }
}
