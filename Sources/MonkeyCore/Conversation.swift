import Foundation

public struct Conversation: Hashable, Sendable, Identifiable {
  public var id: ConversationID
  public var title: String
  public var createdAt: Date
  public var updatedAt: Date
  public var instructions: String
  public var messageCount: Int

  public init(
    id: ConversationID,
    title: String,
    createdAt: Date,
    updatedAt: Date,
    instructions: String = "",
    messageCount: Int = 0
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.instructions = instructions
    self.messageCount = messageCount
  }
}

extension Conversation: Codable {
  enum CodingKeys: String, CodingKey {
    case id, title, instructions
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case messageCount = "message_count"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = ConversationID(rawValue: try container.decode(String.self, forKey: .id))
    title = try container.decode(String.self, forKey: .title)
    instructions = try container.decode(String.self, forKey: .instructions)
    messageCount = try container.decode(Int.self, forKey: .messageCount)

    let createdAtString = try container.decode(String.self, forKey: .createdAt)
    guard let createdAt = ISO8601Milliseconds.date(from: createdAtString) else {
      throw DecodingError.dataCorruptedError(
        forKey: .createdAt, in: container, debugDescription: "Invalid ISO-8601 timestamp")
    }
    self.createdAt = createdAt

    let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
    guard let updatedAt = ISO8601Milliseconds.date(from: updatedAtString) else {
      throw DecodingError.dataCorruptedError(
        forKey: .updatedAt, in: container, debugDescription: "Invalid ISO-8601 timestamp")
    }
    self.updatedAt = updatedAt
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id.rawValue, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(ISO8601Milliseconds.string(from: createdAt), forKey: .createdAt)
    try container.encode(ISO8601Milliseconds.string(from: updatedAt), forKey: .updatedAt)
    try container.encode(instructions, forKey: .instructions)
    try container.encode(messageCount, forKey: .messageCount)
  }
}

extension ConversationID {
  public init(timestampedName: TimestampedName) {
    self.init(rawValue: timestampedName.description)
  }

  public var timestampedName: TimestampedName? {
    TimestampedName(parsing: rawValue)
  }
}
