/// Where conversations are stored, per PLAN.md §3a. The user picks one in
/// Settings; both the app and the CLI read the same choice (see
/// `StorageLocationPreference`).
public enum StorageLocation: String, Codable, Hashable, Sendable {
  case onDevice
  case iCloud
}
