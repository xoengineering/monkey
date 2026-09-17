import Foundation

/// Prints only the newly-appended suffix of a growing message body to stdout,
/// so `ModelSession`'s throttled full-body updates render as an incremental
/// stream in the terminal instead of repeating the whole text each time.
/// `@unchecked Sendable`: guarded by its own lock, safe to call from the
/// `ModelSession.send` `onUpdate` callback regardless of which context it
/// fires from.
final class StreamPrinter: @unchecked Sendable {
  private var printed = ""
  private let lock = NSLock()
  private let write: (String) -> Void

  init(write: @escaping (String) -> Void = StreamPrinter.writeToStandardOutput) {
    self.write = write
  }

  func printDelta(of body: String) {
    lock.lock()
    defer { lock.unlock() }
    guard body.count > printed.count else { return }
    let delta = String(body.dropFirst(printed.count))
    printed = body
    write(delta)
  }

  private static func writeToStandardOutput(_ text: String) {
    print(text, terminator: "")
    fflush(stdout)
  }
}
