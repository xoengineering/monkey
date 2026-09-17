import Foundation

/// Resolves the on-disk conversations root for a given `StorageLocation`,
/// per PLAN.md §3a.
public enum ConversationsRootResolver {
  /// - Returns: `nil` for `.iCloud` when no ubiquity container is available
  ///   (iCloud signed out, disabled, or the entitlement missing) — callers
  ///   should fall back to `.onDevice` in that case rather than failing.
  public static func resolve(
    location: StorageLocation, fileManager: FileManager = .default
  ) -> URL? {
    switch location {
    case .onDevice:
      return AppGroupStorage.conversationsRootURL(fileManager: fileManager)
    case .iCloud:
      guard let ubiquityContainer = fileManager.url(forUbiquityContainerIdentifier: nil) else {
        return nil
      }
      return
        ubiquityContainer
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("Conversations", isDirectory: true)
    }
  }
}
