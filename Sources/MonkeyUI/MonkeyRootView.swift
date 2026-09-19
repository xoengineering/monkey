import MonkeyCore
import SwiftUI
import Textual

public struct MonkeyRootView: View {
  public static let windowID = "main"

  var environment: AppEnvironment
  @Binding var defaultInstructions: String
  @State private var selection: ConversationID?
  /// The conversation just created here, whose composer should take focus
  /// when its detail view appears. Cleared once the selection moves on, so
  /// clicking back to it later behaves like any other sidebar click.
  @State private var newlyCreatedID: ConversationID?
  /// Per window, so it survives switching conversations (the detail view is
  /// recreated per selection) but starts fresh from Settings on relaunch.
  @State private var composerHeight: CGFloat?
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
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button("New Conversation", systemImage: "square.and.pencil", action: createConversation)
          }
          #if os(iOS)
            ToolbarItem(placement: .automatic) {
              Button("Settings", systemImage: "gearshape") {
                showingSettings = true
              }
            }
          #endif
        }
    } detail: {
      let selectedConversation = environment.listViewModel.conversations.first {
        $0.id == selection
      }
      if let conversation = selectedConversation {
        ConversationDetailView(
          conversation: conversation, store: environment.store, backend: environment.backend,
          isSendingDisabled: environment.isMigrating,
          focusesComposerOnAppear: conversation.id == newlyCreatedID,
          composerHeight: $composerHeight,
          onConversationUpdated: { Task { await environment.listViewModel.refresh() } }
        )
        .id(conversation.id)
      } else {
        ContentUnavailableView(
          "No Conversation Selected", systemImage: "bubble.left.and.bubble.right")
      }
    }
    .textual.imageAttachmentLoader(NoFetchImageAttachmentLoader())
    .focusedSceneValue(
      \.conversationActions, ConversationActions(newConversation: createConversation)
    )
    .onChange(of: environment.generation) { selection = nil }
    .onChange(of: selection) {
      if selection != newlyCreatedID { newlyCreatedID = nil }
    }
    #if os(iOS)
      .sheet(isPresented: $showingSettings) {
        SettingsTabsView(defaultInstructions: $defaultInstructions, environment: environment)
      }
    #endif
  }

  private func createConversation() {
    Task {
      if let conversation = await environment.listViewModel.createConversation() {
        newlyCreatedID = conversation.id
        selection = conversation.id
      }
    }
  }
}
