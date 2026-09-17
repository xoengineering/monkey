import MonkeyCore
import SwiftUI
import Textual

public struct MonkeyRootView: View {
  @State private var environment: AppEnvironment
  @State private var selection: ConversationID?
  @State private var showingSettings = false
  @State private var defaultInstructions = ""

  public init(store: ConversationStore, backend: any ChatBackend) {
    _environment = State(initialValue: AppEnvironment(store: store, backend: backend))
  }

  public var body: some View {
    NavigationSplitView {
      ConversationListView(viewModel: environment.listViewModel, selection: $selection)
        .id(environment.generation)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button("Settings", systemImage: "gearshape") {
              showingSettings = true
            }
          }
        }
    } detail: {
      let selectedConversation = environment.listViewModel.conversations.first {
        $0.id == selection
      }
      if let conversation = selectedConversation {
        ConversationDetailView(
          conversation: conversation, store: environment.store, backend: environment.backend,
          onConversationUpdated: { Task { await environment.listViewModel.refresh() } }
        )
        .id(conversation.id)
      } else {
        ContentUnavailableView(
          "No Conversation Selected", systemImage: "bubble.left.and.bubble.right")
      }
    }
    .textual.imageAttachmentLoader(NoFetchImageAttachmentLoader())
    .onChange(of: environment.generation) { selection = nil }
    .sheet(isPresented: $showingSettings) {
      SettingsView(defaultInstructions: $defaultInstructions, environment: environment)
    }
  }
}
