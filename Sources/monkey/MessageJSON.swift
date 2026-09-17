import MonkeyCore

struct MessageJSON: Encodable {
  let id: String
  let role: String
  let createdAt: String
  let status: String
  let model: String
  let inReplyTo: String?
  let tokensPrompt: Int?
  let tokensOutput: Int?
  let error: String?
  let body: String

  enum CodingKeys: String, CodingKey {
    case id, role, status, model, error, body
    case createdAt = "created_at"
    case inReplyTo = "in_reply_to"
    case tokensPrompt = "tokens_prompt"
    case tokensOutput = "tokens_output"
  }

  init(_ message: Message) {
    id = message.id.rawValue
    role = message.role.rawValue
    createdAt = ISO8601Milliseconds.string(from: message.createdAt)
    status = message.status.rawValue
    model = message.model
    inReplyTo = message.inReplyTo?.rawValue
    tokensPrompt = message.tokensPrompt
    tokensOutput = message.tokensOutput
    error = message.error
    body = message.body
  }
}
