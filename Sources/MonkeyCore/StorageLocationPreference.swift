import Foundation

/// Persists the user's `StorageLocation` choice in the app group's shared
/// `UserDefaults` suite, so the app and the bundled CLI agree on which root
/// to read (PLAN.md §5's "iCloud mode works because the CLI reads whichever
/// root the app's Settings selected, via a shared preference in the group
/// container").
public enum StorageLocationPreference {
  private static let key = "storageLocation"

  public static func load(
    defaults: UserDefaults? = UserDefaults(suiteName: AppGroupStorage.groupIdentifier)
  ) -> StorageLocation {
    guard let defaults,
      let rawValue = defaults.string(forKey: key),
      let location = StorageLocation(rawValue: rawValue)
    else {
      return .onDevice
    }
    return location
  }

  public static func save(
    _ location: StorageLocation,
    defaults: UserDefaults? = UserDefaults(suiteName: AppGroupStorage.groupIdentifier)
  ) {
    defaults?.set(location.rawValue, forKey: key)
  }
}
