import SwiftUI

struct ComposerView: View {
  var viewModel: ConversationDetailViewModel
  var isSendingDisabled = false
  var focusesOnAppear = false
  /// The height the user dragged to in this window. `nil` means "use the
  /// Starting Height setting", which stays live until the first drag.
  @Binding var height: CGFloat?
  /// Upper bound from the parent, which knows the window's height and how
  /// much of it the message list must keep.
  var maximumHeight: CGFloat
  @AppStorage(ComposerSettings.startingLinesKey)
  private var startingLines = ComposerSettings.defaultStartingLines
  @FocusState private var isFocused: Bool
  @State private var lineHeight: CGFloat = 17

  /// `TextEditor`'s own vertical text-container padding, so N lines of text
  /// fit without a scroll bar.
  private let editorInsets: CGFloat = 10

  var body: some View {
    VStack(spacing: 0) {
      ComposerResizeHandle(
        height: $height, currentHeight: editorHeight,
        range: minimumHeight...max(maximumHeight, minimumHeight))

      HStack(alignment: .bottom, spacing: 8) {
        TextEditor(
          text: Binding(get: { viewModel.composerText }, set: { viewModel.composerText = $0 })
        )
        .font(.body)
        .frame(height: editorHeight)
        .background {
          // Measures one line of the editor's font, so the Starting Height
          // setting (in lines) converts to points without hardcoding a size.
          Text("X")
            .font(.body)
            .hidden()
            .onGeometryChange(
              for: CGFloat.self, of: { $0.size.height }, action: { lineHeight = $0 })
        }
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
    }
    // The detail view is recreated per selected conversation (`.id(conversation.id)`),
    // so this fires on every selection change; the flag limits it to a just-created
    // conversation, leaving sidebar clicks focused in the sidebar. `defaultFocus`
    // alone won't do it: it only resolves initial focus and never takes focus away
    // from a list that already has it.
    .onAppear {
      if focusesOnAppear { isFocused = true }
    }
  }

  private var minimumHeight: CGFloat { lineHeight + editorInsets }

  private var startingHeight: CGFloat { lineHeight * CGFloat(startingLines) + editorInsets }

  /// Clamped every render, so shrinking the window shrinks the composer with
  /// it and one line always stays visible.
  private var editorHeight: CGFloat {
    let requested = height ?? startingHeight
    return max(min(requested, maximumHeight), minimumHeight)
  }

  private func send() {
    viewModel.send()
  }
}
