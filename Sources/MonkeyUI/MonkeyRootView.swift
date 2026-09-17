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
  #if os(macOS)
    @Environment(\.openSettings) private var openSettings
  #endif

  public init(environment: AppEnvironment, defaultInstructions: Binding<String>) {
    self.environment = environment
    self._defaultInstructions = defaultInstructions
  }

  public var body: some View {
    NavigationSplitView {
      ConversationListView(viewModel: environment.listViewModel, selection: $selection)
        .id(environment.generation)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button("Settings", systemImage: "gearshape") {
              #if os(macOS)
                openSettings()
              #else
                showingSettings = true
              #endif
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
