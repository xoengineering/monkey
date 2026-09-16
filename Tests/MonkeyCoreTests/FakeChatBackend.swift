import FoundationModels

@testable import MonkeyCore

/// A controllable `ChatBackend` double for Core tests, so `ModelSession` behavior can
/// be tested without Apple Intelligence enabled. `@unchecked Sendable` because each
/// test creates and uses its own instance sequentially, never sharing one across
/// concurrent tasks.
final class FakeChatBackend: ChatBackend, @unchecked Sendable {
  enum StreamResult {
    case chunks([String])
    case failure(Error)
  }

  struct RecordedCall {
    var history: [ChatTurn]
    var instructions: String?
    var prompt: String
  }

  let identifier = "fake-model"
  let availability: SystemLanguageModel.Availability
  let contextSize: Int
  let tokensPerTurn: Int
  var results: [StreamResult]
  private(set) var recordedCalls: [RecordedCall] = []

  init(
    availability: SystemLanguageModel.Availability = .available,
    contextSize: Int = 100,
    tokensPerTurn: Int = 10,
    results: [StreamResult] = [.chunks(["Hello"])]
  ) {
    self.availability = availability
    self.contextSize = contextSize
    self.tokensPerTurn = tokensPerTurn
    self.results = results
  }

  func tokenCount(for turns: [ChatTurn], instructions: String?) async throws -> Int {
    var count = turns.count * tokensPerTurn
    if let instructions, !instructions.isEmpty {
      count += tokensPerTurn
    }
    return count
  }

  func streamResponse(
    history: [ChatTurn], instructions: String?, prompt: String
  ) -> AsyncThrowingStream<String, Error> {
    recordedCalls.append(RecordedCall(history: history, instructions: instructions, prompt: prompt))
    let result = results.isEmpty ? .chunks([]) : results.removeFirst()

    return AsyncThrowingStream { continuation in
      switch result {
      case .chunks(let chunks):
        for chunk in chunks {
          continuation.yield(chunk)
        }
        continuation.finish()
      case .failure(let error):
        continuation.finish(throwing: error)
      }
    }
  }
}
