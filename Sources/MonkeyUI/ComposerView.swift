import SwiftUI

struct ComposerView: View {
  var viewModel: ConversationDetailViewModel
  var isSendingDisabled = false
  var focusesOnAppear = false
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      TextEditor(
        text: Binding(get: { viewModel.composerText }, set: { viewModel.composerText = $0 })
      )
      .frame(minHeight: 36, maxHeight: 160)
      .focused($isFocused)
      .onSubmit(send)
      #if os(macOS)
        .onKeyPress(.return, phases: .down) { press in
          if press.modifiers.contains(.command) {
            send()
            return .handled
          }
          return .ignored
        }
      #endif

      if viewModel.isSending {
        Button("Stop", systemImage: "stop.circle.fill") {
          viewModel.stopSending()
        }
        .labelStyle(.iconOnly)
      } else {
        Button("Send", systemImage: "arrow.up.circle.fill") {
          send()
        }
        .labelStyle(.iconOnly)
        .disabled(
          viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(8)
    .disabled(isSendingDisabled)
    // The detail view is recreated per selected conversation (`.id(conversation.id)`),
    // so this fires on every selection change; the flag limits it to a just-created
    // conversation, leaving sidebar clicks focused in the sidebar. `defaultFocus`
    // alone won't do it: it only resolves initial focus and never takes focus away
    // from a list that already has it.
    .onAppear {
      if focusesOnAppear { isFocused = true }
    }
  }

  private func send() {
    viewModel.send()
  }
}
