import Foundation

// MARK: - Safe run iteration
//
// AttributedString.Runs uses IndexingIterator<Runs> which is @frozen/@inlinable
// in the Swift stdlib. When the compiler specializes it, the inlined next() method
// references Runs.Index.== — a symbol that doesn't exist on iOS 16.
//
// These helpers iterate using the Runs subscript that takes AttributedString.Index
// (not Runs.Index), so no Runs.Index comparisons are emitted into our binary.

extension AttributedStringProtocol {
  /// Iterates all runs without referencing `Runs.Index.==`.
  func forEachRun(_ body: (AttributedString.Runs.Run) -> Void) {
    let runs = self.runs
    var position = self.startIndex
    let end = self.endIndex
    while position < end {
      let run = runs[position]
      body(run)
      position = run.range.upperBound
    }
  }

  /// Returns the first run, or nil if the string is empty.
  var firstRun: AttributedString.Runs.Run? {
    guard startIndex < endIndex else { return nil }
    return runs[startIndex]
  }

  /// Maps all runs to an array.
  func mapRuns<T>(_ transform: (AttributedString.Runs.Run) -> T) -> [T] {
    var result: [T] = []
    forEachRun { result.append(transform($0)) }
    return result
  }

  /// Compact-maps all runs to an array.
  func compactMapRuns<T>(_ transform: (AttributedString.Runs.Run) -> T?) -> [T] {
    var result: [T] = []
    forEachRun { if let value = transform($0) { result.append(value) } }
    return result
  }

  /// Returns true if any run satisfies the predicate.
  func containsRun(where predicate: (AttributedString.Runs.Run) -> Bool) -> Bool {
    let runs = self.runs
    var position = self.startIndex
    let end = self.endIndex
    while position < end {
      let run = runs[position]
      if predicate(run) { return true }
      position = run.range.upperBound
    }
    return false
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
    containsRun { run in
      keyPaths.first { keyPath in
        run.attributes[keyPath: keyPath] != nil
      } != nil
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
      let lowerBound: AttributedString.Index
      let intent: PresentationIntent.IntentType?
    }

    typealias Element = BlockRun
    typealias Index = Int

    private let boundaries: [Boundary]
    private let endOfContent: AttributedString.Index

    init(
      attributedString: some AttributedStringProtocol,
      parent: PresentationIntent.IntentType?
    ) {
      var boundaries: [Boundary] = []
      var lastIntent: PresentationIntent.IntentType?
      var endOfContent = attributedString.startIndex

      attributedString.forEachRun { run in
        let intent = run.presentationIntent?.intent(before: parent)

        // Record first run or whenever the intent changes (including nil values)
        if boundaries.isEmpty || intent != lastIntent {
          boundaries.append(.init(lowerBound: run.range.lowerBound, intent: intent))
          lastIntent = intent
        }
        endOfContent = run.range.upperBound
      }

      self.boundaries = boundaries
      self.endOfContent = endOfContent
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
        ? boundaries[position + 1].lowerBound
        : endOfContent

      return BlockRun(intent: boundary.intent, range: boundary.lowerBound..<upperBound)
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
