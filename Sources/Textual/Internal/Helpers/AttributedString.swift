import Foundation

// MARK: - Safe run iteration
//
// AttributedString.Runs.Index.== is missing from Foundation on iOS 16.4, causing a
// dyld crash at load time when any code references the symbol. Every standard iteration
// pattern (for-in, map, contains, first, etc.) desugars to IndexingIterator.next() which
// calls == on Runs.Index.
//
// The helpers below iterate by character position instead: subscripting Runs with an
// AttributedString.Index returns the Run containing that character, and advancing to
// run.range.upperBound moves to the next run without ever touching Runs.Index.==.

extension AttributedStringProtocol {
  func forEachRun(_ body: (AttributedString.Runs.Run) throws -> Void) rethrows {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      for run in runs {
        try body(run)
      }
    } else {
      var position = startIndex
      while position < endIndex {
        let run = runs[position]
        try body(run)
        position = run.range.upperBound
      }
    }
  }

  func mapRuns<T>(_ transform: (AttributedString.Runs.Run) throws -> T) rethrows -> [T] {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return try runs.map(transform)
    } else {
      var result: [T] = []
      var position = startIndex
      while position < endIndex {
        let run = runs[position]
        try result.append(transform(run))
        position = run.range.upperBound
      }
      return result
    }
  }

  func compactMapRuns<T>(
    _ transform: (AttributedString.Runs.Run) throws -> T?
  ) rethrows -> [T] {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return try runs.compactMap(transform)
    } else {
      var result: [T] = []
      var position = startIndex
      while position < endIndex {
        let run = runs[position]
        if let value = try transform(run) {
          result.append(value)
        }
        position = run.range.upperBound
      }
      return result
    }
  }

  var firstRun: AttributedString.Runs.Run? {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return runs.first
    } else {
      guard startIndex < endIndex else { return nil }
      return runs[startIndex]
    }
  }
}

extension AttributedStringProtocol {
  var isMathBlock: Bool {
    let attachments = self.attachments()

    guard
      attachments.count == 1,
      let attachment = attachments.first?.base as? MathAttachment,
      case .block = attachment.displayStyle
    else {
      return false
    }

    return String(self.characters[...])
      .trimmingCharacters(in: .whitespacesAndNewlines) == "\u{FFFC}"
  }

  func attachments() -> Set<AnyAttachment> {
    uniqueValues(for: \.textual.attachment)
  }

  func containsValues<T>(for keyPaths: Set<KeyPath<AttributeContainer, T?>>) -> Bool {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      return runs.contains { run in
        keyPaths.first { keyPath in
          run.attributes[keyPath: keyPath] != nil
        } != nil
      }
    } else {
      var position = startIndex
      while position < endIndex {
        let run = runs[position]
        if keyPaths.first(where: { run.attributes[keyPath: $0] != nil }) != nil {
          return true
        }
        position = run.range.upperBound
      }
      return false
    }
  }

  func uniqueValues<T: Hashable>(for keyPath: KeyPath<AttributeContainer, T?>) -> Set<T> {
    var values: Set<T> = []
    forEachRun { run in
      if let value = run.attributes[keyPath: keyPath] {
        values.insert(value)
      }
    }
    return values
  }

  func slugified() -> String {
    String(
      String(characters[...])
        .lowercased()
        .map { $0.isWhitespace ? "-" : $0 }
        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
    )
  }
}

// MARK: - Iterable view into blocks
//
// BlockRuns segments an AttributedString into block-level runs based on PresentationIntent
// boundaries. Each BlockRun represents a contiguous range where the block-level intent
// (the intent component immediately before the parent intent in the hierarchy) remains constant.
//
// When the intent changes or becomes nil, a new boundary is recorded. This allows iterating
// over structural blocks (paragraphs, list items, table cells) without reconstructing the
// entire block tree.

extension AttributedStringProtocol {
  func blockRuns(parent: PresentationIntent.IntentType? = nil) -> AttributedString.BlockRuns {
    AttributedString.BlockRuns(attributedString: self, parent: parent)
  }
}

extension AttributedString {
  struct BlockRuns: RandomAccessCollection {
    struct BlockRun: Sendable {
      let intent: PresentationIntent.IntentType?
      let range: Range<AttributedString.Index>
    }

    private struct Boundary {
      let charIndex: AttributedString.Index
      let intent: PresentationIntent.IntentType?
    }

    typealias Element = BlockRun
    typealias Index = Int

    private let endCharIndex: AttributedString.Index
    private let boundaries: [Boundary]

    init(
      attributedString: some AttributedStringProtocol,
      parent: PresentationIntent.IntentType?
    ) {
      self.endCharIndex = attributedString.endIndex

      var boundaries: [Boundary] = []
      var lastIntent: PresentationIntent.IntentType?

      attributedString.forEachRun { run in
        let intent = run.presentationIntent?.intent(before: parent)

        // Record first run or whenever the intent changes (including nil values)
        if boundaries.isEmpty || intent != lastIntent {
          boundaries.append(.init(charIndex: run.range.lowerBound, intent: intent))
          lastIntent = intent
        }
      }

      self.boundaries = boundaries
    }

    var startIndex: Index { boundaries.startIndex }
    var endIndex: Index { boundaries.endIndex }

    func index(after i: Index) -> Index {
      boundaries.index(after: i)
    }

    func index(before i: Index) -> Index {
      boundaries.index(before: i)
    }

    subscript(position: Index) -> BlockRun {
      let boundary = boundaries[position]
      let upperBound = (position + 1 < boundaries.count)
        ? boundaries[position + 1].charIndex
        : endCharIndex

      return BlockRun(intent: boundary.intent, range: boundary.charIndex..<upperBound)
    }
  }
}

extension PresentationIntent {
  fileprivate func intent(
    before intent: PresentationIntent.IntentType?
  ) -> PresentationIntent.IntentType? {
    guard let intent else {
      return components.last
    }

    guard
      let index = components.firstIndex(of: intent),
      index != components.startIndex
    else {
      return nil
    }

    return components[components.index(before: index)]
  }
}

// MARK: - NSAttributedString

extension NSAttributedString.Key: TextualCompatible {}

extension TextualNamespace where Base == NSAttributedString.Key {
  static var attachment: Base {
    .init(AttributeScopes.TextualAttributes.AttachmentAttribute.name)
  }

  static var presentationIntent: Base {
    .init(AttributeScopes.FoundationAttributes.PresentationIntentAttribute.name)
  }
}
