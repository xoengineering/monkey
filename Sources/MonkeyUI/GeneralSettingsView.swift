import SwiftUI

struct GeneralSettingsView: View {
  @Binding var defaultInstructions: String
  @AppStorage(ComposerSettings.startingLinesKey)
  private var startingLines = ComposerSettings.defaultStartingLines

  var body: some View {
    Form {
      Section("Default Instructions") {
        TextEditor(text: $defaultInstructions)
          .font(.body)
          .frame(minHeight: 200)
        Text("Used for new conversations. Each conversation can override this.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Message Field") {
        Stepper(
          "Starting Height: ^[\(startingLines) line](inflect: true)",
          value: $startingLines, in: ComposerSettings.startingLinesRange)
        Text(
          """
          Drag the border above the message field to resize it. \
          It never grows past the window, less room for the message list.
          """
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 420, minHeight: 320, alignment: .top)
  }
}
