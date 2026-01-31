import SwiftUI

// MARK: - Overview
//
// `AttachmentOverlay` renders attachment views using resolved `Text.Layout` geometry.
//
// It's applied at the text fragment level. The fragment exposes the resolved layout through the
// `Text.LayoutKey` preference; this modifier reads the anchored layout, converts its anchor to a
// concrete origin using `GeometryReader`, and installs an `AttachmentView` that draws attachments
// at their run bounds.
//
// Note: This feature requires iOS 17+ due to Text.Layout API dependency.

struct AttachmentOverlay: ViewModifier {
  private let attachments: Set<AnyAttachment>

  init(attachments: Set<AnyAttachment>) {
    self.attachments = attachments
  }

  func body(content: Content) -> some View {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      content
        .overlayPreferenceValue(Text.LayoutKey.self) { value in
          if let anchoredLayout = value.first {
            GeometryReader { geometry in
              AttachmentView(
                attachments: attachments,
                origin: geometry[anchoredLayout.origin],
                layout: anchoredLayout.layout
              )
            }
          }
        }
    } else {
      // iOS 16: Attachments overlay is not available
      content
    }
  }
}
