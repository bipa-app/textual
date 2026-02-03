#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  struct EmptyTextLayoutCollection: TextLayoutCollection {
    var layouts: [any TextLayout] {
      []
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      other.layouts.isEmpty
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      false
    }

    func index(of layout: Text.Layout) -> Int? {
      nil
    }
  }
#endif
