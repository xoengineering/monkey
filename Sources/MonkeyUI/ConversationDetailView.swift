import FoundationModels
import MonkeyCore
import SwiftUI

struct ConversationDetailView: View {
  @State private var viewModel: ConversationDetailViewModel

  init(conversation: Conversation, store: ConversationStore, backend: any ChatBackend) {
    _viewModel = State(
      initialValue: ConversationDetailViewModel(
        conversation: conversation, store: store, backend: backend))
  }

  var body: some View {
    Group {
      if case .unavailable(let reason) = viewModel.availability {
        ModelUnavailableView(reason: reason)
      } else {
        VStack(spacing: 0) {
          MessageThreadView(viewModel: viewModel)
          Divider()
          ComposerView(viewModel: viewModel)
        }
      }
    }
    .navigationTitle(viewModel.conversation.title)
    .task { await viewModel.load() }
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
}
