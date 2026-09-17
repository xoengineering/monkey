import Foundation
import MonkeyCore
import Observation

/// Owns the current `ConversationStore` and its list view model, and knows
/// how to switch between the on-device and iCloud roots (PLAN.md §3a) —
/// pulled out of `MonkeyRootView` because switching storage means replacing
/// the store entirely (a `ConversationStore`'s root is fixed at init), not
/// mutating it in place.
@MainActor
@Observable
public final class AppEnvironment {
  public private(set) var store: ConversationStore
  public private(set) var listViewModel: ConversationListViewModel
  public private(set) var currentLocation: StorageLocation
  public private(set) var isMigrating = false
  public private(set) var migrationProgress: (completed: Int, total: Int)?
  public var errorMessage: String?
  /// Bumped every time `store` is replaced, so views that don't otherwise
  /// key off the store (e.g. a sidebar list keyed by conversation, not
  /// store) can force a fresh `.task` via `.id(environment.generation)`.
  public private(set) var generation = 0

  public let backend: any ChatBackend

  public init(
    store: ConversationStore, backend: any ChatBackend,
    currentLocation: StorageLocation = StorageLocationPreference.load()
  ) {
    self.store = store
    self.backend = backend
    self.currentLocation = currentLocation
    self.listViewModel = ConversationListViewModel(store: store)
  }

  /// Switches storage location: migrates every conversation folder from the
  /// current root to the destination root (skipping ones already migrated,
  /// so this is safe to retry), then adopts a new store pointed at the
  /// destination. No-ops if `location` is already current, or if `.iCloud`
  /// is requested but no ubiquity container is available (signed out,
  /// disabled, or the entitlement missing) — surfaced via `errorMessage`.
  public func switchStorageLocation(to location: StorageLocation) async {
    guard location != currentLocation, !isMigrating else { return }

    guard let destinationRoot = ConversationsRootResolver.resolve(location: location) else {
      errorMessage = "iCloud Drive isn't available right now. Check that you're signed in."
      return
    }

    let sourceRoot = store.rootURL
    let direction: ConversationMigrator.Direction =
      location == .iCloud ? .onDeviceToICloud : .iCloudToOnDevice

    isMigrating = true
    migrationProgress = nil
    defer {
      isMigrating = false
      migrationProgress = nil
    }

    do {
      let migrator = ConversationMigrator()
      try await Task.detached {
        _ = try migrator.migrate(
          direction: direction, from: sourceRoot, to: destinationRoot
        ) { completed, total in
          Task { @MainActor in
            self.migrationProgress = (completed, total)
          }
        }
      }.value
    } catch {
      errorMessage = String(describing: error)
      return
    }

    StorageLocationPreference.save(location)
    currentLocation = location
    adopt(store: ConversationStore(rootURL: destinationRoot))
  }

  private func adopt(store newStore: ConversationStore) {
    store = newStore
    listViewModel = ConversationListViewModel(store: newStore)
    generation += 1
  }
}
