import Foundation

/// Moves conversation folders between the on-device and iCloud roots
/// (PLAN.md §3a). Resumable by design: re-running `migrate` after an
/// interruption skips folders already present at the destination, so it's
/// safe to call unconditionally on every launch while a migration is
/// in-progress-per-Settings.
public struct ConversationMigrator: @unchecked Sendable {
  public enum Direction: Sendable {
    case onDeviceToICloud
    case iCloudToOnDevice

    /// `FileManager.setUbiquitous(_:itemAt:destinationURL:)`'s flag: `true`
    /// moves a local item into the ubiquity container, `false` moves an
    /// ubiquitous item back out to a local destination.
    var setsUbiquitous: Bool {
      switch self {
      case .onDeviceToICloud: true
      case .iCloudToOnDevice: false
      }
    }
  }

  public typealias Mover =
    @Sendable (_ direction: Direction, _ source: URL, _ destination: URL)
    throws -> Void

  private let fileManager: FileManager
  private let move: Mover

  public init(fileManager: FileManager = .default, move: Mover? = nil) {
    self.fileManager = fileManager
    self.move =
      move
      ?? { direction, source, destination in
        try FileManager.default.setUbiquitous(
          direction.setsUbiquitous, itemAt: source, destinationURL: destination)
      }
  }

  @discardableResult
  public func migrate(
    direction: Direction, from source: URL, to destination: URL,
    onProgress: (@Sendable (_ completed: Int, _ total: Int) -> Void)? = nil
  ) throws -> Int {
    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

    let entries = try fileManager.contentsOfDirectory(
      at: source, includingPropertiesForKeys: [.isDirectoryKey])
    let folders = entries.filter {
      (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    var migratedCount = 0
    for (index, folder) in folders.enumerated() {
      let destinationFolder = destination.appendingPathComponent(
        folder.lastPathComponent, isDirectory: true)
      if !fileManager.fileExists(atPath: destinationFolder.path) {
        try move(direction, folder, destinationFolder)
        migratedCount += 1
      }
      onProgress?(index + 1, folders.count)
    }
    return migratedCount
  }
}
