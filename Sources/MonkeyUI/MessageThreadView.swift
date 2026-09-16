import MonkeyCore
import SwiftUI

struct MessageThreadView: View {
  var viewModel: ConversationDetailViewModel
  @State private var scrollPosition = ScrollPosition(idType: MessageID.self)

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if viewModel.canLoadOlderMessages {
          Color.clear
            .frame(height: 1)
            .onAppear { loadOlderPreservingScrollPosition() }
        }

        ForEach(viewModel.messages) { message in
          MessageRowView(message: message)
            .id(message.id)
        }
      }
      .padding()
      .scrollTargetLayout()
    }
    .scrollPosition($scrollPosition)
    .defaultScrollAnchor(.bottom)
  }

  private func loadOlderPreservingScrollPosition() {
    let anchorID = viewModel.messages.first?.id
    Task {
      await viewModel.loadOlderMessagesIfNeeded()
      if let anchorID {
        scrollPosition.scrollTo(id: anchorID)
      }
    }
  }
}
