import FoundationModels
import MonkeyCore
import SwiftUI

struct ConversationDetailView: View {
  @State private var viewModel: ConversationDetailViewModel
  var isSendingDisabled = false
  var focusesComposerOnAppear = false
  @Binding var composerHeight: CGFloat?
  @State private var containerHeight: CGFloat = 0

  /// The message list never gives up more than this to the composer.
  private let minimumThreadHeight: CGFloat = 120
  /// Composer padding plus the resize handle, outside the text editor's frame.
  private let composerChromeHeight: CGFloat = 25

  init(
    conversation: Conversation, store: ConversationStore, backend: any ChatBackend,
    isSendingDisabled: Bool = false,
    focusesComposerOnAppear: Bool = false,
    composerHeight: Binding<CGFloat?>,
    onConversationUpdated: (() -> Void)? = nil
  ) {
    _viewModel = State(
      initialValue: ConversationDetailViewModel(
        conversation: conversation, store: store, backend: backend,
        onConversationUpdated: onConversationUpdated))
    self.isSendingDisabled = isSendingDisabled
    self.focusesComposerOnAppear = focusesComposerOnAppear
    self._composerHeight = composerHeight
  }

  var body: some View {
    Group {
      if case .unavailable(let reason) = viewModel.availability {
        ModelUnavailableView(reason: reason)
      } else {
        VStack(spacing: 0) {
          MessageThreadView(viewModel: viewModel)
          ComposerView(
            viewModel: viewModel, isSendingDisabled: isSendingDisabled,
            focusesOnAppear: focusesComposerOnAppear,
            height: $composerHeight, maximumHeight: maximumComposerHeight)
        }
        .onGeometryChange(
          for: CGFloat.self, of: { $0.size.height }, action: { containerHeight = $0 })
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

  private var maximumComposerHeight: CGFloat {
    containerHeight - minimumThreadHeight - composerChromeHeight
  }
}
