import MonkeyCore
import SwiftUI

struct AdvancedSettingsView: View {
  var environment: AppEnvironment
  #if os(macOS)
    @State private var installedPath: String?
  #endif

  var body: some View {
    Form {
      Section("License") {
        Text("Monkey is open source under the MIT License.")
          .font(.caption)
          .foregroundStyle(.secondary)
        // Placeholder URL — point at the real GitHub repo before shipping (PLAN.md §9).
        Link("View LICENSE.md on GitHub", destination: licenseURL)
      }

      #if os(macOS)
        Section("Command Line Tool") {
          Button("Install Command Line Tool…", action: installCommandLineTool)
          if let installedPath {
            Text("Installed at \(installedPath). Run `monkey` from Terminal.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Text("Installs a symlink to the bundled CLI so you can run `monkey` from Terminal.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      #endif
    }
    .padding()
    .frame(minWidth: 420, minHeight: 320)
  }

  private var licenseURL: URL {
    URL(string: "https://github.com/example/monkey/blob/main/LICENSE.md")!
  }

  #if os(macOS)
    private func installCommandLineTool() {
      do {
        if let path = try CLIInstaller.install() {
          installedPath = path
        }
      } catch {
        environment.errorMessage = error.localizedDescription
      }
    }
  #endif
}
