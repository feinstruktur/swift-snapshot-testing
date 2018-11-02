import Foundation

extension Strategy {
  public static var any: Strategy<A, String> {
    return Strategy.lines.pullback { snap($0) }
  }
}

private func snap<T>(_ value: T, name: String? = nil, indent: Int = 0) -> String {
  let indentation = String(repeating: " ", count: indent)
  let mirror = Mirror(reflecting: value)
  let count = mirror.children.count
  let bullet = count == 0 ? "-" : "▿"

  let description: String
  switch (value, mirror.displayStyle) {
  case (_, .collection?):
    description = count == 1 ? "1 element" : "\(count) elements"
  case (_, .dictionary?):
    description = count == 1 ? "1 key/value pair" : "\(count) key/value pairs"
  case (_, .set?):
    description = count == 1 ? "1 member" : "\(count) members"
  case (_, .tuple?):
    description = count == 1 ? "(1 element)" : "(\(count) elements)"
  case (_, .optional?):
    let subjectType = String(describing: mirror.subjectType)
      .replacingOccurrences(of: " #\\d+", with: "", options: .regularExpression)
    description = count == 0 ? "\(subjectType).none" : "\(subjectType)"
  case (let value as SnapshotStringConvertible, _):
    description = value.snapshotDescription
  case (let value as CustomDebugStringConvertible, _):
    description = value.debugDescription
  case (let value as CustomStringConvertible, _):
    description = value.description
  case (_, .class?), (_, .struct?):
    description = String(describing: mirror.subjectType)
      .replacingOccurrences(of: " #\\d+", with: "", options: .regularExpression)
  case (_, .enum?):
    let subjectType = String(describing: mirror.subjectType)
      .replacingOccurrences(of: " #\\d+", with: "", options: .regularExpression)
    description = count == 0 ? "\(subjectType).\(value)" : "\(subjectType)"
  default:
    description = "(indescribable)"
  }

  let sortedChildren: [Mirror.Child]
  switch mirror.displayStyle {
  case .dictionary?:
    sortedChildren =
      mirror.children.sorted(by: { c1, c2 in
      switch (c1.label, c2.label) {
      case let (.some(c1), .some(c2)):
        return c1 < c2
      case (.some, .none):
        return false
      case (.none, .some):
        return true
      case (.none, .none):
        return true
      }
    })
  default:
    // this is very clumsy but I have found no other to convert
    // from to Mirror.Children to [Mirror.Child] (which is what sorted yields)
    sortedChildren = mirror.children.map {$0}
  }
  let lines = ["\(indentation)\(bullet) \(name.map { "\($0): " } ?? "")\(description)\n"]
    + sortedChildren.map { snap($1, name: $0, indent: indent + 2) }

  return lines.joined()
}

public protocol SnapshotStringConvertible {
  var snapshotDescription: String { get }
}

extension Date: SnapshotStringConvertible {
  public var snapshotDescription: String {
    return snapshotDateFormatter.string(from: self)
  }
}

extension NSObject: SnapshotStringConvertible {
    public var snapshotDescription: String {
        return purgePointers(self.debugDescription)
    }
}

extension Data: SnapshotStringConvertible {
    public var snapshotDescription: String {
        return purgePointers(self.debugDescription)
    }
}

private let snapshotDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone(abbreviation: "UTC")
  return formatter
}()

func purgePointers(_ string: String) -> String {
  return string.replacingOccurrences(of: ":?\\s*0x[\\da-f]+(\\s*)", with: "$1", options: .regularExpression)
}
