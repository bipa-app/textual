import SwiftUI

// MARK: - Overview
//
// TextFragment renders attributed content as SwiftUI.Text with support for inline
// attachments, links, and selection. It uses a TextBuilder to construct and cache
// Text values, minimizing rebuilds during resize by keying on attachment sizes.
//
// Attachments are represented as placeholder images tagged with AttachmentAttribute. The
// actual attachment views are rendered in an overlay using the resolved Text.Layout
// geometry. Three modifiers are applied at the fragment level:
//
// - TextSelectionBackground renders selection highlights on macOS
// - AttachmentOverlay draws attachments at their run locations with selection-aware dimming
// - TextLinkInteraction handles tap gestures on links
//
// These overlays use backgroundPreferenceValue and overlayPreferenceValue to access
// Text.Layout and render in fragment-local coordinates. Fragment-level overlays enable
// coordinate space isolation and keep scrollable regions interactive.
//
// An ancestor view must define a named coordinate space (.textContainer) for the text
// container. TextFragment uses onGeometryChange to observe the container size and rebuild
// Text when attachment sizes need to change.
//
// TextFragment is used by InlineText and StructuredText (via BlockContent) to render
// attributed content with inline attachments, links, and selection.

// MARK: - iOS 17+ Implementation using @Observable

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
struct TextFragment17<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment
  @StateObject private var textBuilder: TextBuilder17<Content>

  private let content: Content

  init(_ content: Content, environment: TextEnvironmentValues) {
    self.content = content
    self._textBuilder = StateObject(wrappedValue: TextBuilder17(content, environment: environment))
  }

  var body: some View {
    textBuilder.text
      .customAttribute(TextFragmentAttribute())
      .onGeometryChange(for: CGSize?.self, of: \.textContainerSize) { size in
        guard let size else { return }
        textBuilder.sizeChanged(size, environment: textEnvironment)
      }
      .onChange(of: content) { _, newValue in
        textBuilder.updateContent(newValue, environment: textEnvironment)
      }
      .modifier(TextSelectionBackground())
      .modifier(AttachmentOverlay(attachments: content.attachments()))
      .modifier(TextLinkInteraction())
  }
}

// MARK: - iOS 16 Implementation using ObservableObject

struct TextFragment16<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment
  @StateObject private var textBuilder: TextBuilder16Wrapper<Content>

  private let content: Content

  init(_ content: Content, environment: TextEnvironmentValues) {
    self.content = content
    self._textBuilder = StateObject(wrappedValue: TextBuilder16Wrapper(content, environment: environment))
  }

  var body: some View {
    // Note: On iOS 16, the following features are not available:
    // - customAttribute (iOS 17+)
    // - onGeometryChange (iOS 17+)
    // - onChange(of:initial:) signature (iOS 17+)
    // - Attachments, links, and selection overlays (require Text.Layout which is iOS 17+)
    // Basic text rendering works, but advanced features are disabled.
    text
      .onChange(of: content) { newValue in
        textBuilder.updateContent(newValue, environment: textEnvironment)
      }
  }

  private var text: Text {
    textBuilder.text
  }
}

// Wrapper to handle StateObject initialization
@MainActor
final class TextBuilder16Wrapper<Content: AttributedStringProtocol>: ObservableObject {
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

// MARK: - Cross-version wrapper

struct TextFragment<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment
  private let content: Content

  init(_ content: Content) {
    self.content = content
  }

  var body: some View {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      TextFragment17(content, environment: textEnvironment)
    } else {
      TextFragment16(content, environment: textEnvironment)
    }
  }
}

struct TextFragmentAttribute: TextAttribute {
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Text.Layout {
  var isTextFragment: Bool {
    first?.first?[TextFragmentAttribute.self] != nil
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textContainer: NamedCoordinateSpace {
    .named("textContainer")
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension GeometryProxy {
  fileprivate var textContainerSize: CGSize? {
    bounds(of: .textContainer)?.size
  }
}

// MARK: - Helper extension for Text initialization (shared between builders)

extension Text {
  init(
    attributedString: some AttributedStringProtocol,
    attachmentSizes: [AttachmentKey: CGSize],
    in environment: TextEnvironmentValues
  ) {
    let textValues = attributedString.mapRuns { run in
      var text: Text

      var runEnvironment = environment
      runEnvironment.font = run.font ?? environment.font

      let key = run.textual.attachment.map {
        AttachmentKey(attachment: $0, font: runEnvironment.font)
      }

      if let key, let size = attachmentSizes[key] {
        // Create placeholder with attachment attribute (iOS 17+ only)
        text = Text(placeholderSize: size)
          .baselineOffset(key.attachment.baselineOffset(in: runEnvironment))
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
          text = text.customAttribute(
            AttachmentAttribute(
              key.attachment,
              presentationIntent: run.presentationIntent
            )
          )
        }
      } else {
        text = Text(AttributedString(attributedString[run.range]))
      }

      // Add link attribute for TextLinkInteraction (iOS 17+ only)
      if let link = run.link {
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
          text = text.customAttribute(LinkAttribute(link))
        }
      }

      return text
    }

    self = textValues.reduce(Text(verbatim: "")) { partialResult, text in
      Text("\(partialResult)\(text)")
    }
  }

  init(placeholderSize size: CGSize) {
    self.init(SwiftUI.Image(size: size) { _ in })
  }
}

extension AttributedStringProtocol {
  func attachmentSizes(
    for proposal: ProposedViewSize, in environment: TextEnvironmentValues
  ) -> [AttachmentKey: CGSize] {
    Dictionary(
      self.compactMapRuns { run in
        guard let attachment = run.textual.attachment else {
          return nil
        }
        var environment = environment
        environment.font = run.font ?? environment.font
        return (
          AttachmentKey(
            attachment: attachment,
            font: environment.font
          ),
          attachment.sizeThatFits(proposal, in: environment)
        )
      },
      uniquingKeysWith: { existing, _ in existing }
    )
  }
}
