import Foundation
import Yams

public actor ConversationStore {
  public nonisolated let rootURL: URL
  private let fileManager: FileManager
  private var messageCache: LRUCache<MessageFileName, Message>
  private var filePresenter: ConversationsRootFilePresenter?

  public init(rootURL: URL, fileManager: FileManager = .default, cacheLimit: Int = 500) {
    self.rootURL = rootURL
    self.fileManager = fileManager
    self.messageCache = LRUCache(capacity: cacheLimit)
  }

  /// Registers an `NSFilePresenter` for the root so external writers (the
  /// iCloud daemon syncing another device's changes, or the user editing a
  /// file directly in Finder/Files) evict the affected message from the
  /// cache instead of serving stale content (PLAN.md §3a).
  public func startPresenting() {
    guard filePresenter == nil else { return }
    let presenter = ConversationsRootFilePresenter(rootURL: rootURL) { [weak self] url in
      Task { await self?.invalidateCache(for: url) }
    }
    filePresenter = presenter
    NSFileCoordinator.addFilePresenter(presenter)
  }

  public func stopPresenting() {
    guard let presenter = filePresenter else { return }
    NSFileCoordinator.removeFilePresenter(presenter)
    filePresenter = nil
  }

  private func invalidateCache(for url: URL) {
    guard let fileName = MessageFileName(parsing: url.lastPathComponent) else { return }
    messageCache[fileName] = nil
  }

  public func listConversations() throws -> [Conversation] {
    guard
      let entries = try? fileManager.contentsOfDirectory(
        at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
    else {
      return []
    }

    let conversations = try entries.compactMap { url -> Conversation? in
      let yamlURL = url.appendingPathComponent("conversation.yaml")
      guard fileManager.fileExists(atPath: yamlURL.path) else { return nil }
      let data = try coordinatedRead(at: yamlURL)
      return try YAMLDecoder().decode(Conversation.self, from: data)
    }

    return conversations.sorted { $0.updatedAt > $1.updatedAt }
  }

  @discardableResult
  public func create(title: String) throws -> Conversation {
    let now = Date()
    let id = ConversationID(timestampedName: TimestampedName(timestamp: now))
    let conversation = Conversation(id: id, title: title, createdAt: now, updatedAt: now)

    try fileManager.createDirectory(
      at: directoryURL(for: id), withIntermediateDirectories: true)
    try writeConversationYAML(conversation)

    return conversation
  }

  public func update(_ conversation: Conversation) throws {
    try writeConversationYAML(conversation)
  }

  public func delete(_ id: ConversationID) throws {
    try coordinatedRemove(at: directoryURL(for: id))
    messageCache.removeAll()
  }

  public func messageIndex(for id: ConversationID) throws -> [MessageFileName] {
    let entries = try fileManager.contentsOfDirectory(
      at: directoryURL(for: id), includingPropertiesForKeys: nil)
    return entries.compactMap { MessageFileName(parsing: $0.lastPathComponent) }.sorted()
  }

  public func loadMessage(_ fileName: MessageFileName, in id: ConversationID) throws -> Message {
    if let cached = messageCache[fileName] {
      return cached
    }
    let data = try coordinatedRead(at: messageURL(fileName, in: id))
    let message = try Message.load(from: data)
    messageCache[fileName] = message
    return message
  }

  public func loadMessages(
    _ fileNames: [MessageFileName], in id: ConversationID
  ) throws -> [Message] {
    try fileNames.map { try loadMessage($0, in: id) }
  }

  public func write(_ message: Message, in id: ConversationID) throws {
    let fileName = MessageFileName(
      timestampedName: TimestampedName(timestamp: message.createdAt, key: message.id.rawValue)
    )
    try coordinatedWrite(message.serialized(), to: messageURL(fileName, in: id))
    messageCache[fileName] = message
    try touchConversation(id)
  }

  /// Refreshes `updated_at` and recomputes `message_count` from the directory
  /// listing (the real source of truth) after a message is written.
  private func touchConversation(_ id: ConversationID) throws {
    let yamlURL = directoryURL(for: id).appendingPathComponent("conversation.yaml")
    guard fileManager.fileExists(atPath: yamlURL.path) else { return }

    var conversation = try YAMLDecoder().decode(
      Conversation.self, from: try coordinatedRead(at: yamlURL))
    conversation.updatedAt = Date()
    conversation.messageCount = try messageIndex(for: id).count
    try writeConversationYAML(conversation)
  }

  private func writeConversationYAML(_ conversation: Conversation) throws {
    guard let data = try YAMLEncoder().encode(conversation).data(using: .utf8) else {
      throw FrontmatterDocument.FrontmatterError.invalidEncoding
    }
    try coordinatedWrite(
      data, to: directoryURL(for: conversation.id).appendingPathComponent("conversation.yaml")
    )
  }

  private func coordinatedRead(at url: URL) throws -> Data {
    var coordinatorError: NSError?
    var result: Result<Data, Error>!
    NSFileCoordinator(filePresenter: filePresenter).coordinate(
      readingItemAt: url, options: [], error: &coordinatorError
    ) { coordinatedURL in
      result = Result { try Data(contentsOf: coordinatedURL) }
    }
    if let coordinatorError { throw coordinatorError }
    return try result.get()
  }

  private func coordinatedWrite(_ data: Data, to url: URL) throws {
    var coordinatorError: NSError?
    var writeResult: Result<Void, Error> = .success(())
    NSFileCoordinator(filePresenter: filePresenter).coordinate(
      writingItemAt: url, options: .forReplacing, error: &coordinatorError
    ) { coordinatedURL in
      writeResult = Result {
        let tempURL = coordinatedURL.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: tempURL, options: .atomic)
        _ = try fileManager.replaceItemAt(coordinatedURL, withItemAt: tempURL)
      }
    }
    if let coordinatorError { throw coordinatorError }
    try writeResult.get()
  }

  private func coordinatedRemove(at url: URL) throws {
    var coordinatorError: NSError?
    var removeResult: Result<Void, Error> = .success(())
    NSFileCoordinator(filePresenter: filePresenter).coordinate(
      writingItemAt: url, options: .forDeleting, error: &coordinatorError
    ) { coordinatedURL in
      removeResult = Result { try fileManager.removeItem(at: coordinatedURL) }
    }
    if let coordinatorError { throw coordinatorError }
    try removeResult.get()
  }

  private func directoryURL(for id: ConversationID) -> URL {
    rootURL.appendingPathComponent(id.rawValue, isDirectory: true)
  }

  private func messageURL(_ fileName: MessageFileName, in id: ConversationID) -> URL {
    directoryURL(for: id).appendingPathComponent(fileName.description)
  }
}
