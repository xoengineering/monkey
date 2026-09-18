import MonkeyCore
import SwiftUI
import Textual

public struct MonkeyRootView: View {
  var environment: AppEnvironment
  @Binding var defaultInstructions: String
  @State private var selection: ConversationID?
  #if os(iOS)
    @State private var showingSettings = false
  #endif

  public init(environment: AppEnvironment, defaultInstructions: Binding<String>) {
    self.environment = environment
    self._defaultInstructions = defaultInstructions
  }

  public var body: some View {
    NavigationSplitView {
      ConversationListView(viewModel: environment.listViewModel, selection: $selection)
        .id(environment.generation)
        #if os(iOS)
          .toolbar {
            ToolbarItem(placement: .automatic) {
              Button("Settings", systemImage: "gearshape") {
                showingSettings = true
              }
            }
          }
        #endif
    } detail: {
      let selectedConversation = environment.listViewModel.conversations.first {
        $0.id == selection
      }
      if let conversation = selectedConversation {
        ConversationDetailView(
          conversation: conversation, store: environment.store, backend: environment.backend,
          isSendingDisabled: environment.isMigrating,
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
    #if os(iOS)
      .sheet(isPresented: $showingSettings) {
        SettingsTabsView(defaultInstructions: $defaultInstructions, environment: environment)
      }
    #endif
  }
}
