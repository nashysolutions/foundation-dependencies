//
//  PropertyListValue.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation

/// A value `UserDefaults` is able to store.
///
/// This type exists so that the one endpoint which accepts a heterogeneous value,
/// ``UserDefaultsClient/setPropertyList``, cannot be handed something the store will
/// refuse. `UserDefaults` raises `NSInvalidArgumentException` when asked to hold a
/// value that is not a property list, and that is a crash rather than an error:
/// nothing at the call site can catch it, and nothing in an `Any?` signature warns
/// about it. Every case below is a shape a property list holds, so the mistake is a
/// compiler diagnostic instead.
///
/// Literals build one, so the type is usually invisible at a call site:
///
/// ```swift
/// @Dependency(\.userDefaultsClient) var userDefaults
///
/// userDefaults.setPropertyList(["light", "dark"], forKey: "themes")
/// userDefaults.setPropertyList(["launches": 3, "seen": true], forKey: "state")
/// ```
///
/// ## Which case a number becomes
///
/// Property lists distinguish a Boolean from a number, and an integer from a
/// floating point value, and so does this type. That distinction is not cosmetic:
/// ``UserDefaultsClient/string`` renders a stored `1` as `"1"` whether it arrived as
/// ``boolean(_:)`` or as ``integer(_:)``, but a caller reading the raw value out of
/// a `plist` file sees `<true/>` for one and `<integer>1</integer>` for the other.
/// Write the case you mean rather than relying on a literal to guess, whenever the
/// value is also read by something outside this package.
///
/// ## What is deliberately absent
///
/// There is no reading endpoint that returns one of these. The typed readers cover
/// what a caller wants a value *as*, and ``UserDefaultsClient/contains`` covers
/// whether there is one at all, which between them is everything the retired `object`
/// endpoint was used for. Returning a `PropertyListValue` would also mean deciding
/// which case a live `NSNumber` becomes, and Foundation does not preserve enough to
/// answer that the same way both stores would.
public enum PropertyListValue: Sendable, Equatable {

    /// A Boolean, stored as `<true/>` or `<false/>`.
    case boolean(Bool)

    /// An integer.
    case integer(Int)

    /// A floating point number.
    case double(Double)

    /// A string.
    case string(String)

    /// A date.
    case date(Date)

    /// A blob of bytes.
    case data(Data)

    /// An ordered list of values, whose elements need not share a case.
    case array([PropertyListValue])

    /// A mapping from string keys to values, whose values need not share a case.
    case dictionary([String: PropertyListValue])

    /// The Foundation value a store hands to `UserDefaults`, or holds in its own
    /// dictionary.
    ///
    /// Recursive for the two container cases, so a nested value is converted by the
    /// same rules as a top level one. Every result is a property list type, which is
    /// the guarantee the enum exists to make.
    var foundationValue: Any {
        switch self {
        case .boolean(let flag):
            flag
        case .integer(let number):
            number
        case .double(let number):
            number
        case .string(let text):
            text
        case .date(let date):
            date
        case .data(let data):
            data
        case .array(let values):
            values.map(\.foundationValue)
        case .dictionary(let values):
            values.mapValues(\.foundationValue)
        }
    }
}

// MARK: - Literals

extension PropertyListValue: ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension PropertyListValue: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension PropertyListValue: ExpressibleByFloatLiteral {

    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension PropertyListValue: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PropertyListValue: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: PropertyListValue...) {
        self = .array(elements)
    }
}

extension PropertyListValue: ExpressibleByDictionaryLiteral {

    /// - Note: A duplicated key is a programmer error rather than a value to resolve,
    ///   so this traps rather than choosing one of the two. A dictionary literal with
    ///   the same key twice does the same thing.
    public init(dictionaryLiteral elements: (String, PropertyListValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}
