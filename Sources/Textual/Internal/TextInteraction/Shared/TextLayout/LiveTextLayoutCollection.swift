#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // MARK: - iOS 16 crash prevention
  //
  // These classes store iOS 17+ types (Text.Layout, Text.Layout.Line, etc.) as `Any`
  // to prevent the Swift runtime from referencing those types in the class metadata.
  // When Sentry scans all ObjC classes at app startup, it triggers metadata
  // initialization via swift_getSingletonMetadata. If stored properties reference
  // iOS 17+ types directly, the metadata init crashes on iOS 16 because those
  // types don't exist. Boxing them as `Any` avoids this.

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  final class LiveTextLayoutCollection: TextLayoutCollection {
    private(set) lazy var layouts: [any TextLayout] = makeLayouts()

    private let _base: Any
    private var base: Text.LayoutKey.Value { _base as! Text.LayoutKey.Value }
    private let geometry: GeometryProxy

    init(base: Text.LayoutKey.Value, geometry: GeometryProxy) {
      self._base = base
      self.geometry = geometry
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      base == (other as? LiveTextLayoutCollection)?.base
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      // Same layouts with different origins do not need position reconciliation
      base.map(\.layout) != (other as? LiveTextLayoutCollection)?.base.map(\.layout)
    }

    func index(of layout: Text.Layout) -> Int? {
      layouts.firstIndex { textLayout in
        (textLayout as? LiveTextLayout)?.base == layout
      }
    }

    private func makeLayouts() -> [any TextLayout] {
      base
        // We are only interested in text fragments
        .filter(\.layout.isTextFragment)
        .map { anchoredLayout in
          LiveTextLayout(
            anchoredLayout: anchoredLayout,
            geometry: geometry
          )
        }
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  final class LiveTextLayout: TextLayout {
    var attributedString: NSAttributedString {
      joinedAttributedString.joined
    }

    let origin: CGPoint

    private(set) lazy var bounds: CGRect = makeBounds()
    private(set) lazy var lines: [any TextLine] = makeLines()

    private let _base: Any
    var base: Text.Layout { _base as! Text.Layout }

    private lazy var contents = base.materializeContents()
    private lazy var joinedAttributedString = contents.attributedStrings.joined()

    convenience init(
      anchoredLayout: Text.LayoutKey.AnchoredLayout,
      geometry: GeometryProxy
    ) {
      self.init(
        base: anchoredLayout.layout,
        origin: geometry[anchoredLayout.origin]
      )
    }

    init(base: Text.Layout, origin: CGPoint) {
      self._base = base
      self.origin = origin
    }

    private func makeBounds() -> CGRect {
      base.map(\.typographicBounds.rect)
        .reduce(CGRect.null, CGRectUnion)
    }

    private func makeLines() -> [any TextLine] {
      guard contents.attributedStrings.count > 1 else {
        return base.map {
          LiveTextLine(base: $0)
        }
      }

      // Get the offset mappings on the layout strings to maintain object identity
      let (_, characterOffsets) = contents.layoutAttributedStrings.joined()

      return zip(base, contents.lineFragments).compactMap { line, lineFragment in
        guard let offset = characterOffsets[.init(lineFragment.attributedString)] else {
          return nil
        }

        return LiveTextLine(base: line, offset: offset)
      }
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  final class LiveTextLine: TextLine {
    var origin: CGPoint {
      base.origin
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    private(set) lazy var runs: [any TextRun] = makeRuns()

    private let _base: Any
    var base: Text.Layout.Line { _base as! Text.Layout.Line }
    let offset: Int

    init(base: Text.Layout.Line, offset: Int = 0) {
      self._base = base
      self.offset = offset
    }

    private func makeRuns() -> [any TextRun] {
      if base.isEmpty {
        // Return a newline run for empty lines
        return [
          EmptyRun(
            typographicBounds: base.typographicBounds.rect,
            slice: .init(
              typographicBounds: base.typographicBounds.rect,
              characterRange: offset..<(offset + 1)
            )
          )
        ]
      } else {
        return base.map { run in
          LiveTextRun(base: run, offset: offset)
        }
      }
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  final class LiveTextRun: TextRun {
    var layoutDirection: LayoutDirection {
      base.layoutDirection
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    var url: URL? {
      base.url
    }

    private(set) lazy var slices: [any TextRunSlice] = makeRunSlices()

    private let _base: Any
    var base: Text.Layout.Run { _base as! Text.Layout.Run }
    let offset: Int

    init(base: Text.Layout.Run, offset: Int) {
      self._base = base
      self.offset = offset
    }

    private func makeRunSlices() -> [any TextRunSlice] {
      zip(base, base.characterRanges).map { slice, characterRange in
        LiveTextRunSlice(
          base: slice,
          characterRange: characterRange.offset(by: offset)
        )
      }
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  struct EmptyRun: TextRun {
    let layoutDirection: LayoutDirection = .localeBased()
    let typographicBounds: CGRect
    let url: URL? = nil
    let slice: EmptyRunSlice

    var slices: [any TextRunSlice] {
      [slice]
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  final class LiveTextRunSlice: TextRunSlice {
    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    let characterRange: Range<Int>
    private let _base: Any
    var base: Text.Layout.RunSlice { _base as! Text.Layout.RunSlice }

    init(base: Text.Layout.RunSlice, characterRange: Range<Int>) {
      self._base = base
      self.characterRange = characterRange
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  struct EmptyRunSlice: TextRunSlice {
    let typographicBounds: CGRect
    let characterRange: Range<Int>
  }
#endif
