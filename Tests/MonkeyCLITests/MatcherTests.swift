import Testing

@testable import monkey

@Suite struct MatcherTests {
  @Test func substringMatchIsCaseInsensitive() throws {
    let matcher = try Matcher(query: "blue", useRegex: false)

    #expect(matcher.matches("The sky is Blue."))
    #expect(!matcher.matches("The sky is red."))
  }

  @Test func regexMatchIsCaseInsensitive() throws {
    let matcher = try Matcher(query: "^blue.*", useRegex: true)

    #expect(matcher.matches("Blue skies ahead"))
    #expect(!matcher.matches("skies are Blue"))
  }
}
