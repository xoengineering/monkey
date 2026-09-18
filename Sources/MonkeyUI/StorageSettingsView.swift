import MonkeyCore
import SwiftUI

#if os(macOS)
  import AppKit
#endif

struct StorageSettingsView: View {
  var environment: AppEnvironment

  var body: some View {
    Form {
      Section("Location") {
        Picker("Location", selection: storageLocationBinding) {
          Text("On This Device").tag(StorageLocation.onDevice)
          Text("iCloud Drive").tag(StorageLocation.iCloud)
        }
        .pickerStyle(.inline)
        .labelsHidden()
        .disabled(environment.isMigrating)

        Text(storageLocationExplanation)
          .font(.caption)
          .foregroundStyle(.secondary)

        if environment.isMigrating {
          if let progress = environment.migrationProgress, progress.total > 0 {
            ProgressView(
              "Moving conversations…",
              value: Double(progress.completed), total: Double(progress.total))
          } else {
            ProgressView("Moving conversations…")
          }
        }
      }

      Section("Data Folder") {
        Text(environment.store.rootURL.path)
          .font(.caption)
          .foregroundStyle(.secondary)
        #if os(macOS)
          Button("Show Data Folder in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([environment.store.rootURL])
          }
        #endif
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 420, minHeight: 360, alignment: .top)
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
