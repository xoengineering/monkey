import Foundation

#if os(macOS)
  import AppKit

  enum CLIInstallerError: LocalizedError {
    case destinationAlreadyExists(String)

    var errorDescription: String? {
      switch self {
      case .destinationAlreadyExists(let path):
        "A file already exists at \(path). Remove it manually (for example, run `rm \(path)`"
          + " in Terminal) and try installing again."
      }
    }
  }

  /// Installs a symlink to the bundled CLI binary so the user can run
  /// `monkey` from Terminal. Only ever writes through a user-driven
  /// `NSSavePanel` — per PLAN.md §5, "Never write outside the sandbox
  /// without the panel," since a save panel's user-granted destination is
  /// sandbox-legal to write to even though the App Sandbox otherwise
  /// wouldn't allow it.
  ///
  /// Deliberately does not support overwriting an existing file at the
  /// chosen destination, or persisting access for a later "uninstall."
  /// **[verified]** live, the hard way, across six failed attempts: a plain
  /// `removeItem` on the panel-granted URL fails with EPERM even right
  /// after the panel's own "Replace?" confirmation; `replaceItemAt` fails
  /// with ENOENT on the original item; a `.withSecurityScope` bookmark of
  /// the destination fails before the file exists ("scoped bookmarks can
  /// only be created for existing files or directories"), and fails just
  /// the same afterward for the symlink itself ("could not open() the
  /// item") or for the containing directory (same error — the grant
  /// doesn't extend past the exact chosen path). The one thing that works
  /// reliably: creating the symlink directly, once, at a path nothing
  /// occupies yet. See PLAN.md §6 for the full record.
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

      guard !FileManager.default.fileExists(atPath: destination.path) else {
        throw CLIInstallerError.destinationAlreadyExists(destination.path)
      }

      let bundledBinary =
        Bundle.main.bundleURL
        .appendingPathComponent("Contents/Helpers/monkey")
      try FileManager.default.createSymbolicLink(
        at: destination, withDestinationURL: bundledBinary)
      return destination.path
    }
  }
#endif
