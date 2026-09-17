import Foundation

/// Bridges `NSFilePresenter` (an Objective-C protocol requiring an
/// `NSObject`, which actors can't subclass) into `ConversationStore`'s
/// actor-isolated cache invalidation. Reacts to subitem changes/deletions
/// under the conversations root — PLAN.md §3a's "external changes ... evict
/// cached messages." This works for purely local files too (no iCloud
/// container required), which is what makes it testable without a real
/// ubiquity container: a second `NSFileCoordinator` writing to the same root
/// genuinely triggers these callbacks.
final class ConversationsRootFilePresenter: NSObject, NSFilePresenter {
  let presentedItemURL: URL?
  let presentedItemOperationQueue = OperationQueue()
  private let onSubitemChange: @Sendable (URL) -> Void

  init(rootURL: URL, onSubitemChange: @escaping @Sendable (URL) -> Void) {
    self.presentedItemURL = rootURL
    self.onSubitemChange = onSubitemChange
    super.init()
  }

  func presentedSubitemDidChange(at url: URL) {
    onSubitemChange(url)
  }

  func accommodatePresentedSubitemDeletion(
    at url: URL, completionHandler: @escaping (Error?) -> Void
  ) {
    onSubitemChange(url)
    completionHandler(nil)
  }
}
