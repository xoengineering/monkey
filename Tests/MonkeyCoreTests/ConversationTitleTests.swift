import Testing

@testable import MonkeyCore

@Suite struct ConversationTitleTests {
  @Test func usesTheWholeBodyWhenItIsShort() {
    #expect(ConversationTitle.derive(from: "What color is the sky?") == "What color is the sky?")
  }

  @Test func keepsOnlyTheFirstFewWordsWithAnEllipsis() {
    let body = "Please summarize the following article about ocean currents for me"

    #expect(ConversationTitle.derive(from: body) == "Please summarize the following article about…")
  }

  @Test func capsVeryLongWordsByCharacterCount() {
    let body = String(repeating: "a", count: 80)

    let title = ConversationTitle.derive(from: body)

    #expect(title.count == 49)
    #expect(title.hasSuffix("…"))
  }

  @Test func collapsesNewlinesAndRepeatedWhitespace() {
    #expect(ConversationTitle.derive(from: "  hello\n\n   world  ") == "hello world")
  }

  @Test func fallsBackToUntitledForEmptyBody() {
    #expect(ConversationTitle.derive(from: "   \n ") == Conversation.untitledTitle)
  }
}
