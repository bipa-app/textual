import SwiftUI

// MARK: - Overview
//
// `TextSelectionInteraction` manages the text selection model lifecycle for multiple `Text` fragments.
//
// Selection is opt-in through the `textSelection` environment value. When enabled, the modifier
// observes text layout changes via `overlayTextLayoutCollection` and creates or updates a
// `TextSelectionModel`. The model is then passed to the platform-specific implementation
// (`PlatformTextSelectionInteraction`), which presents the appropriate selection UI for macOS
// or iOS. This separation keeps model management in shared code while platform interactions
// remain independent.
//
// Note: This feature requires iOS 17+ due to Text.Layout API dependency.

struct TextSelectionInteraction: ViewModifier {
  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        TextSelectionInteractionContent17(content: content)
      } else {
        // iOS 16: Text selection is not available
        content
      }
    #else
      content
    #endif
  }
}

#if TEXTUAL_ENABLE_TEXT_SELECTION
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  private struct TextSelectionInteractionContent17<Content: View>: View {
    @Environment(\.textSelection) private var textSelection
    @Environment(TextSelectionCoordinator.self) private var coordinator: TextSelectionCoordinator?

    @State private var model = TextSelectionModel()

    let content: Content

    var body: some View {
      if textSelection.allowsSelection {
        content
          .overlayTextLayoutCollection { layoutCollection in
            Color.clear
              .onChange(of: AnyTextLayoutCollection(layoutCollection), initial: true) {
                model.setCoordinator(coordinator)
                model.setLayoutCollection(layoutCollection)
              }
          }
          .modifier(PlatformTextSelectionInteraction(model: model))
      } else {
        content
      }
    }
  }
#endif

#if TEXTUAL_ENABLE_TEXT_SELECTION
  extension EnvironmentValues {
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    @usableFromInline
    @Entry var textSelection: any TextSelectability.Type = DisabledTextSelectability.self
  }
#endif
