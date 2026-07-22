import Foundation

/// A timestamp owned by the session domain.
///
/// Valid persisted values are canonical, finite UTC seconds. The unchecked
/// initializer deliberately also permits malformed values for validator tests.
public struct SessionTimestamp: Equatable, Hashable, Sendable {
  public let date: Date

  internal init(unchecked date: Date) {
    self.date = date
  }

  public static func == (lhs: SessionTimestamp, rhs: SessionTimestamp) -> Bool {
    let left = lhs.date.timeIntervalSinceReferenceDate
    let right = rhs.date.timeIntervalSinceReferenceDate
    if left.isFinite && right.isFinite {
      return left == right
    }
    return left.bitPattern == right.bitPattern
  }

  public func hash(into hasher: inout Hasher) {
    let value = date.timeIntervalSinceReferenceDate
    if value.isFinite {
      hasher.combine(value)
    } else {
      hasher.combine(value.bitPattern)
    }
  }
}

internal func canonicalSecond(_ date: Date) -> SessionTimestamp? {
  let interval = date.timeIntervalSinceReferenceDate
  guard interval.isFinite else { return nil }
  return SessionTimestamp(unchecked: Date(timeIntervalSinceReferenceDate: interval.rounded(.down)))
}
