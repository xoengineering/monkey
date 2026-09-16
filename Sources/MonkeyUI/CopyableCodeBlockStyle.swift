import SwiftUI
import Textual

/// Wraps Textual's `.gitHub` code block rendering with a copy button in the
/// top-trailing corner, using `CodeBlockProxy.copyToPasteboard()` (Textual
/// handles the macOS/iOS pasteboard difference internally).
struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
  func makeBody(configuration: Configuration) -> some View {
    StructuredText.GitHubCodeBlockStyle().makeBody(configuration: configuration)
      .overlay(alignment: .topTrailing) {
        Button {
          configuration.codeBlock.copyToPasteboard()
        } label: {
          Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(8)
      }
  }
}

extension StructuredText.CodeBlockStyle where Self == CopyableCodeBlockStyle {
  static var monkeyCode: Self { CopyableCodeBlockStyle() }
}
