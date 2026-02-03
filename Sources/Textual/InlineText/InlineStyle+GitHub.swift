import SwiftUI

extension InlineStyle {
  /// The GitHub inline style.
  ///
  /// This style is intended to resemble GitHub's inline text styling, with compact monospaced
  /// and a subtle background for inline code.
  ///
  /// ```swift
  /// InlineText(markdown: "Use `git status` to check **uncommitted** changes")
  ///   .textual.inlineStyle(.gitHub)
  /// ```
  public static var gitHub: InlineStyle {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return InlineStyle()
        .code(.monospaced, .fontScale(0.85), .backgroundColor(.gitHubSecondaryBackground))
        .strong(.fontWeight(.semibold))
        .link(.foregroundColor(.gitHubLink))
    } else {
      // iOS 16 fallback: use single-property API
      var style = InlineStyle()
      style.code = AnyTextProperty(.monospaced)
      style.strong = AnyTextProperty(.fontWeight(.semibold))
      style.link = AnyTextProperty(.foregroundColor(.gitHubLink))
      return style
    }
  }
}
