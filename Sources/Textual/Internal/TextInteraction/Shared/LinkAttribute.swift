import SwiftUI

struct LinkAttribute: TextAttribute {
  var url: URL

  init(_ url: URL) {
    self.url = url
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Text.Layout.Run {
  var url: URL? {
    self[LinkAttribute.self]?.url
  }
}
