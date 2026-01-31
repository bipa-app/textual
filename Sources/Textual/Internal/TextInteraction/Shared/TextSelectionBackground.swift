import SwiftUI

// MARK: - Overview
//
// `TextSelectionBackground` draws selection highlights behind a `Text` fragment.
//
// The platform selection interaction stores a `TextSelectionModel` in the environment at fragment
// scope. This modifier reads the fragment's anchored `Text.Layout` and forwards it to the AppKit
// selection view so it can convert the current selected range into highlight rectangles.
//
// Note: This feature requires iOS 17+ due to Text.Layout API dependency.

struct TextSelectionBackground: ViewModifier {
  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        content
          .backgroundPreferenceValue(Text.LayoutKey.self) { value in
            if let anchoredLayout = value.first {
              GeometryReader { geometry in
                AppKitTextSelectionView(
                  layout: anchoredLayout.layout,
                  origin: geometry[anchoredLayout.origin]
                )
              }
            }
          }
      } else {
        // iOS 16: Text selection background is not available
        content
      }
    #else
      content
    #endif
  }
}
