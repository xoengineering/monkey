import FoundationModels

/// `ChatBackend` implementation backed by the real on-device `SystemLanguageModel`.
/// Never references `PrivateCloudComputeLanguageModel` or any other `LanguageModel`
/// conformer — hard-pinned on-device per the project's network posture.
public struct SystemChatBackend: ChatBackend {
  public init() {}

  public var identifier: String {
    SystemLanguageModel.default.variant.displayName
  }

  public var availability: SystemLanguageModel.Availability {
    SystemLanguageModel.default.availability
  }

  public var contextSize: Int {
    SystemLanguageModel.default.contextSize
  }

  public func tokenCount(for turns: [ChatTurn], instructions: String?) async throws -> Int {
    try await SystemLanguageModel.default.tokenCount(
      for: Self.transcriptEntries(history: turns, instructions: instructions))
  }

  public func streamResponse(
    history: [ChatTurn],
    instructions: String?,
    prompt: String
  ) -> AsyncThrowingStream<String, Error> {
    let entries = Self.transcriptEntries(history: history, instructions: instructions)
    let session = LanguageModelSession(
      model: SystemLanguageModel.default, transcript: Transcript(entries: entries))

    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await snapshot in session.streamResponse(to: prompt) {
            continuation.yield(snapshot.content)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private static func transcriptEntries(
    history: [ChatTurn], instructions: String?
  ) -> [Transcript.Entry] {
    var entries: [Transcript.Entry] = []

    if let instructions, !instructions.isEmpty {
      entries.append(
        .instructions(
          Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: instructions))],
            toolDefinitions: [])))
    }

    for turn in history {
      switch turn.role {
      case .user:
        entries.append(
          .prompt(
            Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: turn.body))])
          ))
      case .assistant:
        entries.append(
          .response(
            Transcript.Response(segments: [.text(Transcript.TextSegment(content: turn.body))])
          ))
      }
    }

    return entries
  }
}
