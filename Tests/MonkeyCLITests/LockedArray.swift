import Foundation

/// A minimal thread-safe append-only array for capturing values from
/// `@Sendable` callbacks in tests.
final class LockedArray<Element>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Element] = []

  func append(_ element: Element) {
    lock.withLock { storage.append(element) }
  }

  var values: [Element] {
    lock.withLock { storage }
  }
}
