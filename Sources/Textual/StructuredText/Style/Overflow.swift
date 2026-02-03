import SwiftUI

/// Controls how content behaves when it overflows horizontally.
public enum OverflowMode: Hashable {
  /// Wraps content to fit the available width.
  case wrap
  /// Allows horizontal scrolling.
  case scroll
}

/// Describes the current overflow behavior and available layout metrics.
public enum OverflowState: Hashable {
  /// Wraps content to fit the available width.
  case wrap
  /// Scrolls horizontally. The container width is provided when available.
  case scroll(containerWidth: CGFloat?)

  /// The scroll container width when available; otherwise `nil`.
  public var containerWidth: CGFloat? {
    guard case .scroll(let containerWidth) = self else {
      return nil
    }
    return containerWidth
  }
}

/// A container that adapts to the current ``OverflowMode``.
///
/// `Overflow` handles content that overflows horizontally. It can switch
/// between wrapping and horizontal scrolling based on an environment value.
///
/// You can set the mode using the ``TextualNamespace/overflowMode(_:)`` modifier. The default is
/// ``OverflowMode/scroll``.
///
/// - Note: You should always use `Overflow` if your custom style needs horizontal scrolling.
///   Using a horizontal `ScrollView` directly will interfere with text selection gestures.
public struct Overflow<Content: View>: View {
  @Environment(\.overflowMode) private var mode
  @State private var containerWidth: CGFloat?
  @State private var contentHeight: CGFloat?

  private let content: (OverflowState) -> Content

  /// Creates an overflow container.
  public init(@ViewBuilder content: @escaping () -> Content) {
    self.init { _ in
      content()
    }
  }

  /// Creates an overflow container that exposes the current overflow state.
  public init(@ViewBuilder content: @escaping (_ state: OverflowState) -> Content) {
    self.content = content
  }

  public var body: some View {
    switch mode {
    case .wrap:
      content(.wrap)
        .frame(maxWidth: .infinity, alignment: .leading)

    case .scroll:
      scrollContent
    }
  }

  @ViewBuilder
  private var scrollContent: some View {
    ScrollView(.horizontal) {
      ZStack {
        // Update the scroll view height when the content height changes
        Color.clear
          .frame(minHeight: contentHeight)
        content(.scroll(containerWidth: containerWidth))
          .onGeometryChange(for: CGFloat.self, of: \.size.height) {
            contentHeight = $0
          }
          // Make text selection local in scrollable regions
          .modifier(TextSelectionInteraction())
          .modifier(TextLayoutKeyTransform())
      }
    }
    .modifier(ScrollGeometryObserver(containerWidth: $containerWidth))
    // Propagate gesture exclusion area
    .modifier(OverflowFramePropagator())
  }
}

// MARK: - iOS 17+ Availability Wrappers

/// Propagates gesture exclusion area using textContainer coordinate space (iOS 17+)
private struct OverflowFramePropagator: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      content
        .background(
          GeometryReader { geometry in
            Color.clear
              .preference(
                key: OverflowFrameKey.self,
                value: [geometry.frame(in: .textContainer)]
              )
          }
        )
    } else {
      // iOS 16: textContainer coordinate space not available, skip gesture exclusion
      content
    }
  }
}

/// Wraps Text.LayoutKey.self transformPreference which requires iOS 17+
private struct TextLayoutKeyTransform: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      content
        .transformPreference(Text.LayoutKey.self) { value in
          value = []
        }
    } else {
      content
    }
  }
}

/// Wraps onScrollGeometryChange which requires iOS 18+
private struct ScrollGeometryObserver: ViewModifier {
  @Binding var containerWidth: CGFloat?

  func body(content: Content) -> some View {
    if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *) {
      content
        .onScrollGeometryChange(for: CGFloat.self, of: \.containerSize.width) {
          containerWidth = $1
        }
    } else if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      // Fallback for iOS 17: use GeometryReader to measure container
      content
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear { containerWidth = geometry.size.width }
              .onChange(of: geometry.size.width) { _, newValue in
                containerWidth = newValue
              }
          }
        )
    } else {
      // Fallback for iOS 16: use older onChange signature
      content
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear { containerWidth = geometry.size.width }
              .onChange(of: geometry.size.width) { newValue in
                containerWidth = newValue
              }
          }
        )
    }
  }
}

extension EnvironmentValues {
  @usableFromInline
  @Entry var overflowMode = OverflowMode.scroll
}
