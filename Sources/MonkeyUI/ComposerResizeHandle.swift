import SwiftUI

/// The draggable border between the message list and the composer, like the
/// one between the sidebar and the detail. Dragging up grows the composer.
struct ComposerResizeHandle: View {
  /// The dragged height; set on the first movement and kept for the window.
  @Binding var height: CGFloat?
  /// What the composer is currently rendering at, so a drag starts from the
  /// visible size even when `height` is still `nil` (settings-derived).
  var currentHeight: CGFloat
  var range: ClosedRange<CGFloat>
  @State private var dragStartHeight: CGFloat?

  var body: some View {
    Divider()
      // A 1pt line is too thin to grab; the frame widens the hit area.
      .frame(height: 9)
      .contentShape(Rectangle())
      #if os(macOS)
        .pointerStyle(.rowResize)
      #endif
      .gesture(
        // Global, not local: the handle moves with the composer as it grows, so
        // a local translation would be measured against a moving origin and
        // the composer would follow the pointer at half speed.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { value in
            let startHeight = dragStartHeight ?? currentHeight
            dragStartHeight = startHeight
            let proposed = startHeight - value.translation.height
            height = min(max(proposed, range.lowerBound), range.upperBound)
          }
          .onEnded { _ in dragStartHeight = nil }
      )
  }
}
