import Foundation

enum CLIOutput {
  static func printJSON(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    print(String(bytes: data, encoding: .utf8) ?? "")
  }
}

func printError(_ message: String) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
}
