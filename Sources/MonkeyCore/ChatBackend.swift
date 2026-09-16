import FoundationModels

/// A narrow seam in front of `SystemLanguageModel`/`LanguageModelSession`.
///
/// Apple's own `LanguageModel` protocol isn't a lightweight testing seam — conforming
/// to it means implementing a full `LanguageModelExecutor` (request/response streaming
/// internals), which is impractical to fake. `ChatBackend` abstracts only what
/// `ModelSession` actually needs, so tests can supply `FakeChatBackend` instead of
/// requiring Apple Intelligence to be enabled.
public protocol ChatBackend: Sendable {
  var identifier: String { get }
  var availability: SystemLanguageModel.Availability { get }
  var contextSize: Int { get }

  func tokenCount(for turns: [ChatTurn], instructions: String?) async throws -> Int

  func streamResponse(
    history: [ChatTurn],
    instructions: String?,
    prompt: String
  ) -> AsyncThrowingStream<String, Error>
}
