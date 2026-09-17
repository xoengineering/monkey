import Foundation
import Testing

@testable import MonkeyCore

@Suite struct ConversationMigratorTests {
  private func makeTemporaryRoot(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  private func makeConversationFolder(named name: String, in root: URL) throws -> URL {
    let folder = root.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("id: \(name)".utf8).write(to: folder.appendingPathComponent("conversation.yaml"))
    return folder
  }

  @Test func movesEveryFolderNotAlreadyAtTheDestination() throws {
    let source = try makeTemporaryRoot("source")
    let destination = try makeTemporaryRoot("destination")
    try makeConversationFolder(named: "one", in: source)
    try makeConversationFolder(named: "two", in: source)

    let movedPairs = LockedArray<(URL, URL)>()
    let migrator = ConversationMigrator { _, sourceURL, destinationURL in
      movedPairs.append((sourceURL, destinationURL))
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    let migratedCount = try migrator.migrate(
      direction: .onDeviceToICloud, from: source, to: destination)

    #expect(migratedCount == 2)
    #expect(movedPairs.values.count == 2)
    #expect(
      FileManager.default.fileExists(atPath: destination.appendingPathComponent("one").path))
    #expect(
      FileManager.default.fileExists(atPath: destination.appendingPathComponent("two").path))
  }

  @Test func skipsFoldersAlreadyPresentAtTheDestinationResumingAnInterruptedMigration() throws {
    let source = try makeTemporaryRoot("source")
    let destination = try makeTemporaryRoot("destination")
    try makeConversationFolder(named: "already-migrated", in: source)
    try makeConversationFolder(named: "not-yet-migrated", in: source)
    try makeConversationFolder(named: "already-migrated", in: destination)

    let movedNames = LockedArray<String>()
    let migrator = ConversationMigrator { _, sourceURL, destinationURL in
      movedNames.append(sourceURL.lastPathComponent)
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    let migratedCount = try migrator.migrate(
      direction: .onDeviceToICloud, from: source, to: destination)

    #expect(migratedCount == 1)
    #expect(movedNames.values == ["not-yet-migrated"])
  }

  @Test func reportsProgressForEveryFolderConsideredIncludingSkipped() throws {
    let source = try makeTemporaryRoot("source")
    let destination = try makeTemporaryRoot("destination")
    try makeConversationFolder(named: "already-migrated", in: source)
    try makeConversationFolder(named: "not-yet-migrated", in: source)
    try makeConversationFolder(named: "already-migrated", in: destination)

    let migrator = ConversationMigrator { _, sourceURL, destinationURL in
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    let progressUpdates = LockedArray<(Int, Int)>()
    _ = try migrator.migrate(
      direction: .onDeviceToICloud, from: source, to: destination
    ) { completed, total in
      progressUpdates.append((completed, total))
    }

    #expect(progressUpdates.values.count == 2)
    #expect(progressUpdates.values.allSatisfy { $0.1 == 2 })
  }

  @Test func passesTheCorrectDirectionToTheMover() throws {
    let source = try makeTemporaryRoot("source")
    let destination = try makeTemporaryRoot("destination")
    try makeConversationFolder(named: "one", in: source)

    let recordedDirections = LockedArray<ConversationMigrator.Direction>()
    let migrator = ConversationMigrator { direction, sourceURL, destinationURL in
      recordedDirections.append(direction)
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    _ = try migrator.migrate(direction: .iCloudToOnDevice, from: source, to: destination)

    #expect(recordedDirections.values == [.iCloudToOnDevice])
  }
}
