public enum MessageStatus: String, Codable, Hashable, Sendable {
  case complete
  case streaming
  case cancelled
  case failed
}
