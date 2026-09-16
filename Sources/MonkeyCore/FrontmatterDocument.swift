import Foundation
import Yams

/// Splits a file into a `---`-fenced YAML frontmatter block and a markdown body.
/// Only the split is custom; the YAML itself is decoded/encoded by Yams.
public enum FrontmatterDocument {
  public enum FrontmatterError: Error, Equatable {
    case invalidEncoding
    case missingOpeningFence
    case missingClosingFence
  }

  public static func parse<T: Decodable>(_ data: Data, as type: T.Type) throws -> (
    metadata: T, body: String
  ) {
    guard let raw = String(data: data, encoding: .utf8) else {
      throw FrontmatterError.invalidEncoding
    }

    let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.components(separatedBy: "\n")

    guard lines.first == "---" else {
      throw FrontmatterError.missingOpeningFence
    }
    guard let closingIndex = lines[1...].firstIndex(of: "---") else {
      throw FrontmatterError.missingClosingFence
    }

    let yamlText = lines[1..<closingIndex].joined(separator: "\n")
    var bodyLines = Array(lines[(closingIndex + 1)...])
    if bodyLines.first == "" {
      bodyLines.removeFirst()
    }
    let body = bodyLines.joined(separator: "\n")

    let metadata = try YAMLDecoder().decode(T.self, from: yamlText)
    return (metadata, body)
  }

  public static func serialize<T: Encodable>(metadata: T, body: String) throws -> Data {
    let yamlText = try YAMLEncoder().encode(metadata)
    let trimmedYAML = yamlText.hasSuffix("\n") ? String(yamlText.dropLast()) : yamlText
    let content = "---\n\(trimmedYAML)\n---\n\n\(body)"

    guard let data = content.data(using: .utf8) else {
      throw FrontmatterError.invalidEncoding
    }
    return data
  }
}
