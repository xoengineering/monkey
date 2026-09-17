import SwiftUI

/// The Settings window's content (three tabs). On macOS this is presented in
/// a native `Settings` scene (⌘, opens it automatically); on iOS/iPadOS,
/// which has no `Settings` scene equivalent, `MonkeyRootView` presents this
/// same view in a sheet instead.
public struct SettingsTabsView: View {
  @Binding var defaultInstructions: String
  var environment: AppEnvironment

  public init(defaultInstructions: Binding<String>, environment: AppEnvironment) {
    self._defaultInstructions = defaultInstructions
    self.environment = environment
  }

  public var body: some View {
    TabView {
      GeneralSettingsView(defaultInstructions: $defaultInstructions)
        .tabItem { Label("General", systemImage: "gearshape") }

      StorageSettingsView(environment: environment)
        .tabItem { Label("Storage", systemImage: "folder") }

      AdvancedSettingsView(environment: environment)
        .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
    }
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
}
