public struct ChatTurn: Hashable, Sendable {
  public var role: MessageRole
  public var body: String

  public init(role: MessageRole, body: String) {
    self.role = role
    self.body = body
  }
}
