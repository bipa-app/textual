import SwiftUI

// MARK: - Overview
//
// Platform abstraction for UIFont/NSFont and font descriptor resolution. The UIKit path
// reads legibilityWeight and dynamicTypeSize from TextEnvironmentValues to construct a
// UITraitCollection, ensuring font descriptors reflect the same Dynamic Type and Bold Text
// settings as the SwiftUI environment.

#if canImport(AppKit)
  typealias PlatformFont = NSFont
  typealias FontDescriptor = NSFontDescriptor
#elseif canImport(UIKit)
  typealias PlatformFont = UIFont
  typealias FontDescriptor = UIFontDescriptor
#endif

extension FontDescriptor {
  static func preferredFontDescriptor(
    withTextStyle style: Font.TextStyle,
    in environment: TextEnvironmentValues
  ) -> FontDescriptor {
    #if canImport(AppKit)
      return preferredFontDescriptor(forTextStyle: .init(style))
    #elseif canImport(UIKit) && !os(watchOS)
      if #available(iOS 17, tvOS 17, *) {
        return preferredFontDescriptor(
          withTextStyle: .init(style),
          compatibleWith: UITraitCollection(
            legibilityWeight: .init(environment.legibilityWeight)
          )
          .modifyingTraits {
            $0.preferredContentSizeCategory = .init(environment.dynamicTypeSize)
          }
        )
      } else {
        // iOS 16: Use traitsUpdating instead of modifyingTraits
        let baseTraits = UITraitCollection(legibilityWeight: .init(environment.legibilityWeight))
        let sizeTraits = UITraitCollection(preferredContentSizeCategory: .init(environment.dynamicTypeSize))
        let combinedTraits = UITraitCollection(traitsFrom: [baseTraits, sizeTraits])
        return preferredFontDescriptor(
          withTextStyle: .init(style),
          compatibleWith: combinedTraits
        )
      }
    #else
      return preferredFontDescriptor(withTextStyle: .init(style))
    #endif
  }
}

extension PlatformFont.TextStyle {
  init(_ textStyle: Font.TextStyle) {
    switch textStyle {
    case .largeTitle:
      #if os(tvOS)
        self = .title1
      #else
        self = .largeTitle
      #endif
    case .title:
      self = .title1
    case .title2:
      self = .title2
    case .title3:
      self = .title3
    case .headline:
      self = .headline
    case .subheadline:
      self = .subheadline
    case .body:
      self = .body
    case .callout:
      self = .callout
    case .footnote:
      self = .footnote
    case .caption:
      self = .caption1
    case .caption2:
      self = .caption2
    #if os(visionOS)
      case .extraLargeTitle:
        self = .extraLargeTitle
      case .extraLargeTitle2:
        self = .extraLargeTitle2
    #endif
    @unknown default:
      self = .body
    }
  }
}

#if canImport(UIKit)
  extension PlatformFont {
    static func custom(
      _ name: String,
      size: CGFloat,
      relativeTo textStyle: Font.TextStyle,
      in environment: TextEnvironmentValues
    ) -> PlatformFont {
      guard let font = UIFont(name: name, size: size) else {
        #if os(watchOS)
          return .preferredFont(forTextStyle: .init(textStyle))
        #else
          return preferredFontForEnvironment(textStyle: textStyle, environment: environment)
        #endif
      }

      let fontMetrics = UIFontMetrics(forTextStyle: .init(textStyle))
      #if os(watchOS)
        return fontMetrics.scaledFont(for: font)
      #else
        return scaledFontForEnvironment(font: font, fontMetrics: fontMetrics, environment: environment)
      #endif
    }

    #if !os(watchOS)
      private static func preferredFontForEnvironment(
        textStyle: Font.TextStyle,
        environment: TextEnvironmentValues
      ) -> PlatformFont {
        if #available(iOS 17, tvOS 17, *) {
          return .preferredFont(
            forTextStyle: .init(textStyle),
            compatibleWith: UITraitCollection(
              legibilityWeight: .init(environment.legibilityWeight)
            ).modifyingTraits {
              $0.preferredContentSizeCategory = .init(environment.dynamicTypeSize)
            }
          )
        } else {
          // iOS 16: Combine trait collections
          let baseTraits = UITraitCollection(legibilityWeight: .init(environment.legibilityWeight))
          let sizeTraits = UITraitCollection(preferredContentSizeCategory: .init(environment.dynamicTypeSize))
          let combinedTraits = UITraitCollection(traitsFrom: [baseTraits, sizeTraits])
          return .preferredFont(forTextStyle: .init(textStyle), compatibleWith: combinedTraits)
        }
      }

      private static func scaledFontForEnvironment(
        font: UIFont,
        fontMetrics: UIFontMetrics,
        environment: TextEnvironmentValues
      ) -> PlatformFont {
        if #available(iOS 17, tvOS 17, *) {
          return fontMetrics.scaledFont(
            for: font,
            compatibleWith: UITraitCollection(
              legibilityWeight: .init(environment.legibilityWeight)
            ).modifyingTraits {
              $0.preferredContentSizeCategory = .init(environment.dynamicTypeSize)
            }
          )
        } else {
          // iOS 16: Combine trait collections
          let baseTraits = UITraitCollection(legibilityWeight: .init(environment.legibilityWeight))
          let sizeTraits = UITraitCollection(preferredContentSizeCategory: .init(environment.dynamicTypeSize))
          let combinedTraits = UITraitCollection(traitsFrom: [baseTraits, sizeTraits])
          return fontMetrics.scaledFont(for: font, compatibleWith: combinedTraits)
        }
      }
    #endif
  }
#endif
