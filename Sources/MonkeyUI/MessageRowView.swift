import MonkeyCore
import SwiftUI
import Textual

struct MessageRowView: View {
  let message: Message

  var body: some View {
    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
      StructuredText(markdown: message.body)
        .textual.structuredTextStyle(.gitHub)
        .textual.codeBlockStyle(.monkeyCode)
        .textual.textSelection(.enabled)
        .padding(10)
        .background(backgroundColor, in: .rect(cornerRadius: 12))

      if message.status == .cancelled {
        Label("Cancelled", systemImage: "xmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if message.status == .failed {
        Label(message.error ?? "Failed", systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }

  private var backgroundColor: Color {
    message.role == .user ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12)
  }
}
