import SwiftUI

// MARK: - Overview
//
// TextBuilder constructs SwiftUI.Text from attributed content with inline attachments.
// It caches Text values keyed by attachment sizes to avoid unnecessary rebuilds during
// resize. When the container size changes, attachment sizes are recomputed and the cache
// is consulted. If the new sizes hash to the same key, the cached Text is reused.
//
// The cache key is derived from the hash of [AttachmentKey: CGSize]. Since attachment
// sizes often remain constant or repeat during incremental resize (e.g., window resizing),
// this compact key enables effective caching without storing the full proposal or
// attributed string. The cache has a count limit of 10 to prevent unbounded growth.
//
// Runs with attachments are converted to placeholder images sized by the attachment's
// sizeThatFits(_:in:) result. Placeholders are tagged with AttachmentAttribute so overlays
// can identify and render the actual attachment views at the resolved layout positions.
//
// On iOS 16, the TextBuilder16Wrapper class provides an ObservableObject-based implementation
// while iOS 17+ uses the @Observable-based TextBuilder17 for better SwiftUI integration.

// MARK: - Cache Key Types

struct AttachmentKey: Hashable {
  let attachment: AnyAttachment
  let font: Font?
}

/// A hashable representation of attachment sizes for use as cache key.
/// We need this because CGSize is only Hashable in iOS 18+.
struct AttachmentSizesCacheKey: Hashable {
  private let sizes: [AttachmentKey: HashableCGSize]

  init(_ sizes: [AttachmentKey: CGSize]) {
    self.sizes = sizes.mapValues { HashableCGSize($0) }
  }
}

// MARK: - iOS 17+ Implementation using @Observable

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor final class TextBuilder17<Content: AttributedStringProtocol> : ObservableObject {
  @Published var text: Text

private var content: Content
private let cache: NSCache<KeyBox<AttachmentSizesCacheKey>, Box<Text>>

  init(_ content: Content, environment: TextEnvironmentValues) {
    let attachmentSizes = content.attachmentSizes(for: .unspecified, in: environment)

    self.text = Text(
      attributedString: content,
      attachmentSizes: attachmentSizes,
      in: environment
    )
    self.content = content
    self.cache = NSCache()
    self.cache.countLimit = 10

    self.cache.setObject(Box(self.text), forKey: KeyBox(AttachmentSizesCacheKey(attachmentSizes)))
  }

  func updateContent(_ content: Content, environment: TextEnvironmentValues) {
    self.content = content
    let attachmentSizes = content.attachmentSizes(for: .unspecified, in: environment)
    self.text = Text(
      attributedString: content,
      attachmentSizes: attachmentSizes,
      in: environment
    )
    self.cache.removeAllObjects()
    self.cache.setObject(Box(self.text), forKey: KeyBox(AttachmentSizesCacheKey(attachmentSizes)))
  }

  func sizeChanged(_ size: CGSize, environment: TextEnvironmentValues) {
    let attachmentSizes = content.attachmentSizes(for: .init(size), in: environment)
    let cacheKey = KeyBox(AttachmentSizesCacheKey(attachmentSizes))

    if let text = cache.object(forKey: cacheKey) {
      self.text = text.wrappedValue
    } else {
      let text = Text(
        attributedString: content,
        attachmentSizes: attachmentSizes,
        in: environment
      )
      cache.setObject(Box(text), forKey: cacheKey)

      self.text = text
    }
  }
}
