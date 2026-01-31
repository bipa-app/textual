import Foundation
import CoreGraphics

final class Box<Value> {
  var wrappedValue: Value

  init(_ wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }
}

struct WeakBox<Wrapped: AnyObject> {
  weak var wrapped: Wrapped?

  init(_ wrapped: Wrapped) {
    self.wrapped = wrapped
  }
}

final class KeyBox<Value: Hashable>: NSObject {
  var wrappedValue: Value

  init(_ wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  override var hash: Int {
    var hasher = Hasher()
    hasher.combine(wrappedValue)
    return hasher.finalize()
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? KeyBox<Value> else {
      return false
    }
    return wrappedValue == other.wrappedValue
  }
}

// MARK: - Hashable CGSize wrapper for use in dictionaries on iOS 16+
// CGSize only conforms to Hashable in iOS 18+, so we need a wrapper

struct HashableCGSize: Hashable {
  let width: CGFloat
  let height: CGFloat

  init(_ size: CGSize) {
    self.width = size.width
    self.height = size.height
  }

  var cgSize: CGSize {
    CGSize(width: width, height: height)
  }
}
