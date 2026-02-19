import SwiftUI

// MARK: - Overview
//
// HighlightedTextFragment displays syntax-highlighted code using a two-phase approach.
// Tokenization runs asynchronously and is keyed by content, while highlighting runs
// synchronously on token or environment changes (theme, color scheme, dynamic type).
//
// The presentationIntent is preserved after highlighting so pasteboard formatters can
// reconstruct the block structure when copying code.

// MARK: - iOS 17+ Implementation using @Observable

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
struct HighlightedTextFragment17: View {
  @Environment(\.textEnvironment) private var textEnvironment

  @StateObject private var model = HighlightedTextFragmentModel17()

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    TextFragment(model.highlightedCode ?? AttributedString(content))
      .foregroundStyle(theme.foregroundColor)
      .task(id: content) {
        await model.tokenize(
          content: content,
          languageHint: languageHint
        )
      }
      .onChange(of: Tuple(model.tokens, textEnvironment)) { _, newValue in
        model.highlight(
          tokens: newValue.values.0,
          presentationIntent: content.presentationIntent,
          using: theme,
          environment: newValue.values.1
        )
      }
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor final class HighlightedTextFragmentModel17: ObservableObject {
  @Published var tokens: [CodeToken] = []
  @Published var highlightedCode: AttributedString?

  func tokenize(content: AttributedSubstring, languageHint: String?) async {
    let code = String(content.characters[...])
    tokens = [CodeToken(content: code, type: .plain)]

    if let tokenizer = CodeTokenizer.shared, let languageHint {
      tokens = await tokenizer.tokenize(code: code, language: languageHint)
    }
  }

  func highlight(
    tokens: [CodeToken],
    presentationIntent: PresentationIntent?,
    using theme: StructuredText.HighlighterTheme,
    environment: TextEnvironmentValues
  ) {
    var attributes = AttributeContainer()
    // Re-apply the presentation intent for pasteboard formatters
    attributes.presentationIntent = presentationIntent
    ForegroundColorProperty(theme.foregroundColor)
      .apply(in: &attributes, environment: environment)
    var highlightedCode = AttributedString()

    for token in tokens {
      var content = AttributedString(token.content)
      var tokenAttributes = attributes

      if let tokenProperties = theme.tokenProperties[token.type] {
        tokenProperties.apply(in: &tokenAttributes, environment: environment)
      }

      content.mergeAttributes(tokenAttributes)
      highlightedCode.append(content)
    }

    self.highlightedCode = highlightedCode
  }
}

// MARK: - iOS 16 Implementation using ObservableObject

struct HighlightedTextFragment16: View {
  @Environment(\.textEnvironment) private var textEnvironment

  @StateObject private var model = HighlightedTextFragmentModel16()

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    TextFragment(model.highlightedCode ?? AttributedString(content))
      .foregroundStyle(theme.foregroundColor)
      .task(id: content) {
        await model.tokenize(
          content: content,
          languageHint: languageHint
        )
      }
      .onChange(of: model.tokens) { newValue in
        model.highlight(
          tokens: newValue,
          presentationIntent: content.presentationIntent,
          using: theme,
          environment: textEnvironment
        )
      }
      .onChange(of: textEnvironment) { newValue in
        model.highlight(
          tokens: model.tokens,
          presentationIntent: content.presentationIntent,
          using: theme,
          environment: newValue
        )
      }
  }
}

@MainActor final class HighlightedTextFragmentModel16: ObservableObject {
  @Published var tokens: [CodeToken] = []
  @Published var highlightedCode: AttributedString?

  func tokenize(content: AttributedSubstring, languageHint: String?) async {
    let code = String(content.characters[...])
    tokens = [CodeToken(content: code, type: .plain)]

    if let tokenizer = CodeTokenizer.shared, let languageHint {
      tokens = await tokenizer.tokenize(code: code, language: languageHint)
    }
  }

  func highlight(
    tokens: [CodeToken],
    presentationIntent: PresentationIntent?,
    using theme: StructuredText.HighlighterTheme,
    environment: TextEnvironmentValues
  ) {
    var attributes = AttributeContainer()
    // Re-apply the presentation intent for pasteboard formatters
    attributes.presentationIntent = presentationIntent
    ForegroundColorProperty(theme.foregroundColor)
      .apply(in: &attributes, environment: environment)
    var highlightedCode = AttributedString()

    for token in tokens {
      var content = AttributedString(token.content)
      var tokenAttributes = attributes

      if let tokenProperties = theme.tokenProperties[token.type] {
        tokenProperties.apply(in: &tokenAttributes, environment: environment)
      }

      content.mergeAttributes(tokenAttributes)
      highlightedCode.append(content)
    }

    self.highlightedCode = highlightedCode
  }
}

// MARK: - Cross-version wrapper

struct HighlightedTextFragment: View {
  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      HighlightedTextFragment17(content, languageHint: languageHint, theme: theme)
    } else {
      HighlightedTextFragment16(content, languageHint: languageHint, theme: theme)
    }
  }
}
