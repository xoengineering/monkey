import Foundation
import Testing

@testable import MonkeyCore

private struct SampleMetadata: Codable, Equatable {
  let id: String
  let count: Int
}

@Suite struct FrontmatterDocumentTests {
  @Test func roundTripsMetadataAndBody() throws {
    let metadata = SampleMetadata(id: "k7x2q9", count: 3)
    let data = try FrontmatterDocument.serialize(metadata: metadata, body: "Hello, world.")

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.metadata == metadata)
    #expect(result.body == "Hello, world.")
  }

  @Test func preservesLiteralFenceMarkersInBody() throws {
    let metadata = SampleMetadata(id: "a", count: 1)
    let body = "line1\n---\nline3"
    let data = try FrontmatterDocument.serialize(metadata: metadata, body: body)

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.body == body)
  }

  @Test func handlesEmptyBody() throws {
    let metadata = SampleMetadata(id: "a", count: 1)
    let data = try FrontmatterDocument.serialize(metadata: metadata, body: "")

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.body == "")
  }

  @Test func handlesCRLFInput() throws {
    let raw = "---\r\nid: a\r\ncount: 1\r\n---\r\n\r\nHello there."
    let data = try #require(raw.data(using: .utf8))

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.metadata == SampleMetadata(id: "a", count: 1))
    #expect(result.body == "Hello there.")
  }

  @Test func handlesUnicodeInBodyAndMetadata() throws {
    let metadata = SampleMetadata(id: "🐒monkey", count: 1)
    let body = "こんにちは — café ☕️"
    let data = try FrontmatterDocument.serialize(metadata: metadata, body: body)

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.metadata == metadata)
    #expect(result.body == body)
  }

  @Test func ignoresUnknownYAMLKeys() throws {
    let raw = "---\nid: a\ncount: 1\nextra_field: surprise\n---\n\nBody text\n"
    let data = try #require(raw.data(using: .utf8))

    let result = try FrontmatterDocument.parse(data, as: SampleMetadata.self)

    #expect(result.metadata == SampleMetadata(id: "a", count: 1))
  }

  @Test func throwsOnMissingOpeningFence() {
    let data = Data("id: a\ncount: 1\n".utf8)
    #expect(throws: FrontmatterDocument.FrontmatterError.self) {
      try FrontmatterDocument.parse(data, as: SampleMetadata.self)
    }
  }

  @Test func throwsOnMissingClosingFence() {
    let data = Data("---\nid: a\ncount: 1\n".utf8)
    #expect(throws: FrontmatterDocument.FrontmatterError.self) {
      try FrontmatterDocument.parse(data, as: SampleMetadata.self)
    }
  }
}
