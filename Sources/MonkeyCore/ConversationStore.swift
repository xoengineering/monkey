import Foundation
import Yams

public actor ConversationStore {
  private let rootURL: URL
  private let fileManager: FileManager
  private var messageCache: LRUCache<MessageFileName, Message>

  public init(rootURL: URL, fileManager: FileManager = .default, cacheLimit: Int = 500) {
    self.rootURL = rootURL
    self.fileManager = fileManager
    self.messageCache = LRUCache(capacity: cacheLimit)
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
      let data = try Data(contentsOf: yamlURL)
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
    try fileManager.removeItem(at: directoryURL(for: id))
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
    let data = try Data(contentsOf: messageURL(fileName, in: id))
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
    try writeAtomically(message.serialized(), to: messageURL(fileName, in: id))
    messageCache[fileName] = message
  }

  private func writeConversationYAML(_ conversation: Conversation) throws {
    guard let data = try YAMLEncoder().encode(conversation).data(using: .utf8) else {
      throw FrontmatterDocument.FrontmatterError.invalidEncoding
    }
    try writeAtomically(
      data, to: directoryURL(for: conversation.id).appendingPathComponent("conversation.yaml")
    )
  }

  private func writeAtomically(_ data: Data, to url: URL) throws {
    let tempURL = url.appendingPathExtension("tmp-\(UUID().uuidString)")
    try data.write(to: tempURL, options: .atomic)
    _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
  }

  private func directoryURL(for id: ConversationID) -> URL {
    rootURL.appendingPathComponent(id.rawValue, isDirectory: true)
  }

  private func messageURL(_ fileName: MessageFileName, in id: ConversationID) -> URL {
    directoryURL(for: id).appendingPathComponent(fileName.description)
  }
}
