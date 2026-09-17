import MonkeyCore
import SwiftUI

#if os(macOS)
  import AppKit
#endif

struct SettingsView: View {
  @Binding var defaultInstructions: String
  var environment: AppEnvironment

  var body: some View {
    Form {
      Section("Default Instructions") {
        TextEditor(text: $defaultInstructions)
          .frame(minHeight: 100)
        Text("Used for new conversations. Each conversation can override this.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Storage") {
        Picker("Location", selection: storageLocationBinding) {
          Text("On This Device").tag(StorageLocation.onDevice)
          Text("iCloud Drive").tag(StorageLocation.iCloud)
        }
        .pickerStyle(.inline)
        .disabled(environment.isMigrating)

        Text(storageLocationExplanation)
          .font(.caption)
          .foregroundStyle(.secondary)

        if environment.isMigrating {
          if let progress = environment.migrationProgress, progress.total > 0 {
            ProgressView(
              "Moving conversations…",
              value: Double(progress.completed), total: Double(progress.total)
            )
          } else {
            ProgressView("Moving conversations…")
          }
        }

        LabeledContent("Data Folder", value: environment.store.rootURL.path)
          .font(.caption)
        #if os(macOS)
          Button("Show Data Folder in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([environment.store.rootURL])
          }
        #endif
      }

      Section("About") {
        LabeledContent("License", value: "MIT")
      }
    }
    .padding()
    .frame(minWidth: 420, minHeight: 480)
    .alert(
      "Something Went Wrong",
      isPresented: Binding(
        get: { environment.errorMessage != nil },
        set: { if !$0 { environment.errorMessage = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(environment.errorMessage ?? "")
    }
  }

  private var storageLocationBinding: Binding<StorageLocation> {
    Binding(
      get: { environment.currentLocation },
      set: { newValue in Task { await environment.switchStorageLocation(to: newValue) } }
    )
  }

  private var storageLocationExplanation: String {
    switch environment.currentLocation {
    case .onDevice:
      "Conversations stay only on this device. Nothing leaves it."
    case .iCloud:
      "Conversations sync via iCloud Drive to your other devices signed into the same Apple ID."
        + " Monkey itself still never opens a network connection — the system's iCloud daemon"
        + " moves the files."
    }
  }
}
