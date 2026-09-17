import SwiftUI

struct GeneralSettingsView: View {
  @Binding var defaultInstructions: String

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
    }
    .padding()
    .frame(minWidth: 420, minHeight: 320)
  }
}
