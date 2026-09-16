import Foundation

public struct Message: Hashable, Sendable {
  public var id: MessageID
  public var role: MessageRole
  public var createdAt: Date
  public var status: MessageStatus
  public var model: String
  public var inReplyTo: MessageID?
  public var tokensPrompt: Int?
  public var tokensOutput: Int?
  public var error: String?
  public var body: String

  public init(
    id: MessageID,
    role: MessageRole,
    createdAt: Date,
    status: MessageStatus,
    model: String,
    inReplyTo: MessageID? = nil,
    tokensPrompt: Int? = nil,
    tokensOutput: Int? = nil,
    error: String? = nil,
    body: String
  ) {
    self.id = id
    self.role = role
    self.createdAt = createdAt
    self.status = status
    self.model = model
    self.inReplyTo = inReplyTo
    self.tokensPrompt = tokensPrompt
    self.tokensOutput = tokensOutput
    self.error = error
    self.body = body
  }
}

extension Message: Codable {
  enum CodingKeys: String, CodingKey {
    case id, role, status, model, error
    case createdAt = "created_at"
    case inReplyTo = "in_reply_to"
    case tokensPrompt = "tokens_prompt"
    case tokensOutput = "tokens_output"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = MessageID(rawValue: try container.decode(String.self, forKey: .id))
    role = try container.decode(MessageRole.self, forKey: .role)
    status = try container.decode(MessageStatus.self, forKey: .status)
    model = try container.decode(String.self, forKey: .model)

    let createdAtString = try container.decode(String.self, forKey: .createdAt)
    guard let createdAt = ISO8601Milliseconds.date(from: createdAtString) else {
      throw DecodingError.dataCorruptedError(
        forKey: .createdAt, in: container, debugDescription: "Invalid ISO-8601 timestamp")
    }
    self.createdAt = createdAt

    let inReplyToString = try container.decodeIfPresent(String.self, forKey: .inReplyTo) ?? ""
    inReplyTo = inReplyToString.isEmpty ? nil : MessageID(rawValue: inReplyToString)

    let tokensPromptValue = try container.decodeIfPresent(Int.self, forKey: .tokensPrompt) ?? 0
    tokensPrompt = tokensPromptValue == 0 ? nil : tokensPromptValue

    let tokensOutputValue = try container.decodeIfPresent(Int.self, forKey: .tokensOutput) ?? 0
    tokensOutput = tokensOutputValue == 0 ? nil : tokensOutputValue

    let errorString = try container.decodeIfPresent(String.self, forKey: .error) ?? ""
    error = errorString.isEmpty ? nil : errorString

    body = ""
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id.rawValue, forKey: .id)
    try container.encode(role, forKey: .role)
    try container.encode(ISO8601Milliseconds.string(from: createdAt), forKey: .createdAt)
    try container.encode(status, forKey: .status)
    try container.encode(model, forKey: .model)
    try container.encode(inReplyTo?.rawValue ?? "", forKey: .inReplyTo)
    try container.encode(tokensPrompt ?? 0, forKey: .tokensPrompt)
    try container.encode(tokensOutput ?? 0, forKey: .tokensOutput)
    try container.encode(error ?? "", forKey: .error)
  }
}

extension Message {
  public static func load(from data: Data) throws -> Message {
    let (metadata, body) = try FrontmatterDocument.parse(data, as: Message.self)
    var message = metadata
    message.body = body
    return message
  }

  public func serialized() throws -> Data {
    try FrontmatterDocument.serialize(metadata: self, body: body)
  }
}
