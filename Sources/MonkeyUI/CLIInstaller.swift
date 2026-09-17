import Foundation

#if os(macOS)
  import AppKit

  /// Installs a symlink to the bundled CLI binary so the user can run
  /// `monkey` from Terminal. Only ever writes through a user-driven
  /// `NSSavePanel` — per PLAN.md §5, "Never write outside the sandbox
  /// without the panel," since a save panel's user-granted destination is
  /// sandbox-legal to write to even though the App Sandbox otherwise
  /// wouldn't allow it.
  enum CLIInstaller {
    /// - Returns: the destination path on success, `nil` if the user
    ///   canceled the panel.
    @MainActor
    static func install() throws -> String? {
      let panel = NSSavePanel()
      panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
      panel.nameFieldStringValue = "monkey"
      panel.prompt = "Install"
      panel.message = "Choose where to install the monkey command line tool."
      panel.canCreateDirectories = true

      guard panel.runModal() == .OK, let destination = panel.url else { return nil }

      let bundledBinary =
        Bundle.main.bundleURL
        .appendingPathComponent("Contents/Helpers/monkey")
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.createSymbolicLink(
        at: destination, withDestinationURL: bundledBinary)
      return destination.path
    }
  }
#endif
