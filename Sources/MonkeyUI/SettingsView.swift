import MonkeyCore
import SwiftUI

struct SettingsView: View {
  @Binding var defaultInstructions: String

  var body: some View {
    Form {
      Section("Default Instructions") {
        TextEditor(text: $defaultInstructions)
          .frame(minHeight: 100)
        Text("Used for new conversations. Each conversation can override this.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("About") {
        LabeledContent("License", value: "MIT")
      }
    }
    .padding()
    .frame(minWidth: 360, minHeight: 320)
  }
}
