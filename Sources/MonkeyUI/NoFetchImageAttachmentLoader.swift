import SwiftUI
import Textual

/// Textual's default image loader fetches remote images over the network
/// (`URLAttachmentLoader` → `ImageLoader.shared` → real HTTP fetch) — a hard
/// violation of this app's no-network posture the first time a message body
/// contains a markdown image link. This loader replaces it: it never performs
/// I/O, and instead renders a tappable link showing the URL, matching PLAN.md's
/// "no image fetching" rule.
struct NoFetchImageAttachmentLoader: AttachmentLoader {
  func attachment(
    for url: URL, text: String, environment: ColorEnvironmentValues
  ) async throws -> RemoteImagePlaceholderAttachment {
    RemoteImagePlaceholderAttachment(url: url)
  }
}

struct RemoteImagePlaceholderAttachment: Attachment {
  let url: URL

  var description: String { url.absoluteString }

  var selectionStyle: AttachmentSelectionStyle { .text }

  var body: some View {
    Link(url.absoluteString, destination: url)
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  // Rough monospace-ish estimate rather than exact text measurement — this
  // is a defensive placeholder (its job is to never fetch anything), not a
  // pixel-perfect layout, so an approximate size is an acceptable tradeoff.
  func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    let averageCharacterWidth: CGFloat = 7
    let lineHeight: CGFloat = 18
    let idealWidth = CGFloat(url.absoluteString.count) * averageCharacterWidth
    let width = min(proposal.width ?? idealWidth, idealWidth)
    return CGSize(width: width, height: lineHeight)
  }
}
