import SwiftUI
import Textual

/// Wraps Textual's `.gitHub` code block rendering with a "Copy" button in the
/// row of space below it, using `CodeBlockProxy.copyToPasteboard()` (Textual
/// handles the macOS/iOS pasteboard difference internally).
struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      StructuredText.GitHubCodeBlockStyle().makeBody(configuration: configuration)

      Button("Copy", systemImage: "doc.on.doc") {
        configuration.codeBlock.copyToPasteboard()
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}

extension StructuredText.CodeBlockStyle where Self == CopyableCodeBlockStyle {
  static var monkeyCode: Self { CopyableCodeBlockStyle() }
}
