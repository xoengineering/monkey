extension Conversation {
  public static let untitledTitle = "Untitled"
}

/// Derives a conversation title from the first message the user sends, so a
/// conversation stops being "Untitled" the moment it has content.
public enum ConversationTitle {
  public static func derive(
    from body: String, maxWords: Int = 6, maxCharacters: Int = 48
  ) -> String {
    let words = body.split(whereSeparator: \.isWhitespace)
    guard !words.isEmpty else { return Conversation.untitledTitle }

    var title = words.prefix(maxWords).joined(separator: " ")
    var truncated = words.count > maxWords
    if title.count > maxCharacters {
      title = String(title.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces)
      truncated = true
    }
    return truncated ? title + "…" : title
  }
}
