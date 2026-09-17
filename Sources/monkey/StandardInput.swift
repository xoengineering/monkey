import Foundation

enum StandardInput {
  /// If stdin isn't a TTY, appends its contents to the given prompt text
  /// (`cat file.md | monkey do "summarize"`), per PLAN.md §5.
  static func appendingPipedInput(to prompt: String) -> String {
    guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else {
      return prompt
    }
    let piped =
      String(bytes: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return combine(prompt: prompt, piped: piped)
  }

  static func combine(prompt: String, piped: String) -> String {
    let trimmedPiped = piped.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPiped.isEmpty else { return prompt }
    return prompt.isEmpty ? trimmedPiped : "\(prompt)\n\n\(trimmedPiped)"
  }
}
