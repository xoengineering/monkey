import Foundation

/// Resolves the on-disk root for conversations shared between the app and the
/// bundled CLI via the app group container (see PLAN.md §3a). Falls back to
/// Application Support when the app group container isn't available — e.g. an
/// unsigned `swift build`/`swift test` product with no entitlements at all.
public enum AppGroupStorage {
  public static let groupIdentifier = "group.engineering.xo.Monkey"

  public static func conversationsRootURL(fileManager: FileManager = .default) -> URL {
    let base =
      fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
      ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent("Conversations", isDirectory: true)
  }
}
