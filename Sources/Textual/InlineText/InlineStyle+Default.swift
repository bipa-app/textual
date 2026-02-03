import SwiftUI

extension InlineStyle {
  /// The default inline style used by ``InlineText`` and ``StructuredText``.
  ///
  /// This style uses a slightly smaller monospaced font for inline code, semibold weight for
  /// strong text, and a link color that adapts to the current appearance.
  public static var `default`: InlineStyle {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return InlineStyle()
        .code(.monospaced, .fontScale(0.94))
        .strong(.fontWeight(.semibold))
        .link(.foregroundColor(DynamicColor.link))
    } else {
      // iOS 16 fallback: use single-property API
      var style = InlineStyle()
      style.code = AnyTextProperty(.monospaced)
      style.strong = AnyTextProperty(.fontWeight(.semibold))
      style.link = AnyTextProperty(.foregroundColor(DynamicColor.link))
      return style
    }
  }
}
