import Testing

@testable import monkey

@Suite struct StandardInputTests {
  @Test func returnsPromptUnchangedWhenPipedInputIsEmpty() {
    #expect(StandardInput.combine(prompt: "summarize", piped: "") == "summarize")
  }

  @Test func usesPipedInputAloneWhenPromptIsEmpty() {
    #expect(StandardInput.combine(prompt: "", piped: "file contents") == "file contents")
  }

  @Test func appendsPipedInputAfterThePromptWithABlankLine() {
    #expect(
      StandardInput.combine(prompt: "summarize", piped: "file contents")
        == "summarize\n\nfile contents")
  }

  @Test func trimsWhitespaceFromPipedInput() {
    #expect(
      StandardInput.combine(prompt: "summarize", piped: "  file contents\n\n")
        == "summarize\n\nfile contents")
  }
}
