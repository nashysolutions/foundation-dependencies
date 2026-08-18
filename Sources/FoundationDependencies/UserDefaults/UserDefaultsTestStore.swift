//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// An in-memory implementation of ``UserDefaultsStoreProtocol`` for use in tests.
///
/// Values live in a dictionary owned by the instance, so a test neither reads nor
/// writes a real `UserDefaults` suite and nothing survives the process. Create one
/// per test to get a clean store.
///
/// ## Fidelity to live `UserDefaults`
///
/// A test double is only worth having if a test that passes against it would also
/// pass against production. `UserDefaults` coerces between types on read rather
/// than returning a default whenever the stored type differs from the requested
/// one, so the typed readers here reproduce those coercions instead of casting the
/// stored value directly. Reading a stored `"42"` through ``int`` returns `42`, and
/// reading a stored `"YES"` through ``bool`` returns `true`, exactly as they would
/// in production.
///
/// The rules are not the obvious ones, and they are not symmetrical between
/// readers, so ``LiveUserDefaultsSemantics`` documents each one against a measured
/// example. Every rule was measured against a real `UserDefaults` suite rather than
/// taken from the prose documentation, which describes the coercions only in
/// general terms.
///
/// Writes are validated the same way. `UserDefaults` raises
/// `NSInvalidArgumentException` when asked to store a value that is not a property
/// list type, so ``setObject`` traps on the same input rather than accepting it
/// into the dictionary.
///
/// ## Known divergence
///
/// ``object`` returns the value as it was written, whereas live `UserDefaults`
/// returns the Foundation counterpart it normalised the value into on write. A
/// value stored through ``setInt`` therefore reads back from ``object`` as an `Int`
/// here and as an `NSNumber` in production, which matters only to a test that casts
/// the result to a different type than it stored: `object(key) as? Bool` finds a
/// `Bool` in production for a stored `1` and finds nothing here. The typed readers
/// are unaffected, and are the endpoints a test should prefer.
///
/// ## Thread safety
///
/// The `Sendable` conformance is `@unchecked` because `storage` is mutable state on
/// a class, which the compiler cannot prove is free of races on its own. What makes
/// it safe is that `storage` is `private` and every closure that touches it is
/// declared `@MainActor`, so all access is serialised on the main actor. Adding an
/// endpoint that reads or writes `storage` from anywhere other than a `@MainActor`
/// closure would break that guarantee, and no compiler diagnostic would point back
/// at this conformance when it did.
public final class UserDefaultsTestStore: UserDefaultsStoreProtocol, @unchecked Sendable {

    /// The backing store, keyed exactly as `UserDefaults` would key it.
    ///
    /// Only ever read or written from the `@MainActor` closures below. See the
    /// thread safety note on the type.
    private var storage: [String: Any] = [:]

    /// Creates an empty store.
    public init() {}

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key.
    ///
    /// Numbers are true when non-zero. Strings are true only when they spell
    /// `"YES"` or `"true"` in any casing, or are exactly `"1"`. Everything else,
    /// including a missing key, is `false`.
    public var bool: @MainActor @Sendable (String) -> Bool {
        { key in
            LiveUserDefaultsSemantics.boolean(from: self.storage[key])
        }
    }

    /// Retrieves an integer value for the specified key.
    ///
    /// Doubles truncate toward zero and strings must be an optionally signed run of
    /// digits in full. Anything that cannot be read as a whole number, including a
    /// missing key, is `0`.
    public var int: @MainActor @Sendable (String) -> Int {
        { key in
            LiveUserDefaultsSemantics.integer(from: self.storage[key])
        }
    }

    /// Retrieves a double value for the specified key.
    ///
    /// Strings contribute their leading numeric run, so `"3.14abc"` reads as
    /// `3.14`. Anything with no numeric prefix, including a missing key, is `0`.
    public var double: @MainActor @Sendable (String) -> Double {
        { key in
            LiveUserDefaultsSemantics.double(from: self.storage[key])
        }
    }

    /// Retrieves a string value for the specified key.
    ///
    /// Numbers are stringified the way `NSNumber` stringifies them, so a stored
    /// `3.0` reads as `"3"` and a stored `true` reads as `"1"`. Dates, data and
    /// arrays have no string form and read as `nil`, as does a missing key.
    public var string: @MainActor @Sendable (String) -> String? {
        { key in
            LiveUserDefaultsSemantics.string(from: self.storage[key])
        }
    }

    /// Retrieves an array of strings for the specified key.
    ///
    /// Returns `nil` unless every element is a string, so an array of numbers reads
    /// as `nil` rather than as an empty array.
    public var stringArray: @MainActor @Sendable (String) -> [String]? {
        { key in
            LiveUserDefaultsSemantics.stringArray(from: self.storage[key])
        }
    }

    /// Retrieves the stored value for the specified key, or `nil` if there is none.
    ///
    /// Unlike the typed readers this performs no coercion. See the known divergence
    /// note on the type for how the returned value differs from production.
    public var object: @MainActor @Sendable (String) -> Any? {
        { key in
            self.storage[key]
        }
    }

    /// Retrieves a `Date` value for the specified key.
    ///
    /// Returns `nil` when the stored value is anything other than a date. A number
    /// is not interpreted as a time interval, matching production.
    public var date: @MainActor @Sendable (String) -> Date? {
        { key in
            self.storage[key] as? Date
        }
    }

    /// Removes the value associated with the specified key.
    public var removeObject: @MainActor @Sendable (String) -> Void {
        { key in
            self.storage.removeValue(forKey: key)
        }
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @MainActor @Sendable (Bool, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores an integer value for the specified key.
    public var setInt: @MainActor @Sendable (Int, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores a double value for the specified key.
    public var setDouble: @MainActor @Sendable (Double, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores a string value for the specified key, or removes the key when `value`
    /// is `nil`.
    public var setString: @MainActor @Sendable (String?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    /// Stores an array of strings for the specified key, or removes the key when
    /// `value` is `nil`.
    public var setStringArray: @MainActor @Sendable ([String]?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    /// Stores a raw value for the specified key, or removes the key when `value` is
    /// `nil`.
    ///
    /// - Precondition: `value` is a property list value. `UserDefaults` raises
    ///   `NSInvalidArgumentException` for anything else, so accepting it here would
    ///   let a test pass against behaviour production does not have. Note that this
    ///   rejects `URL`, which production also rejects through this endpoint even
    ///   though its dedicated `set(_:forKey:)` overload for URLs accepts one.
    public var setObject: @MainActor @Sendable (Any?, String) -> Void {
        { value, key in
            if let value {
                precondition(
                    PropertyListSerialization.propertyList(value, isValidFor: .binary),
                    """
                    Cannot store a value of type \(type(of: value)) for key '\(key)'. \
                    UserDefaults accepts only property list values: String, a number, \
                    Bool, Date, Data, or an Array or Dictionary of those with String \
                    keys. Live UserDefaults raises NSInvalidArgumentException here.
                    """
                )
            }
            self.write(value, forKey: key)
        }
    }

    /// Stores a `Date` value for the specified key, or removes the key when `value`
    /// is `nil`.
    public var setDate: @MainActor @Sendable (Date?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    // MARK: - Storage

    /// Stores `value` under `key`, removing the key when `value` is `nil`.
    ///
    /// Live `UserDefaults` treats a `nil` write as a removal rather than storing an
    /// empty placeholder, so afterwards both stores agree that the key is absent.
    /// The setters that cannot receive `nil` assign to `storage` directly instead of
    /// calling this.
    ///
    /// Isolated to the main actor because it touches `storage`, which the type's
    /// `Sendable` conformance assumes is only ever reached from there. The
    /// annotation makes that a compiler check for this one function rather than
    /// something a future caller has to remember.
    @MainActor
    private func write(_ value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}

/// The type coercions live `UserDefaults` applies when the stored value is not
/// already the type being read.
///
/// Each rule below was measured against a real `UserDefaults` suite rather than
/// inferred from the documentation, which says only that values are converted. The
/// measured rules differ from the obvious guesses in three ways worth knowing:
///
/// - The string readers do not agree with each other. ``integer(from:)`` demands a
///   whole-string match while ``double(from:)`` takes a numeric prefix, so
///   `"42abc"` reads as `0` through one and `42.0` through the other.
/// - ``integer(from:)`` is 32-bit when reading a string and 64-bit otherwise, so a
///   string can saturate where an equivalent stored number does not.
/// - ``boolean(from:)`` accepts far fewer spellings than `NSString.boolValue` does.
///   `"2"` and `"y"` are both `false` here and both `true` through that property.
private enum LiveUserDefaultsSemantics {

    /// Reproduces `UserDefaults.bool(forKey:)`.
    ///
    /// A number is `true` when it is not zero, so `2`, `-1` and `0.5` are all
    /// `true`. A string is `true` only when it reads as `"yes"` or `"true"` in any
    /// casing, or is exactly `"1"`; `"2"`, `"01"`, `" 1"` and `"y"` are all `false`.
    /// Dates, arrays, data and a missing key are `false`.
    static func boolean(from value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            flag
        case let number as Int:
            number != 0
        case let number as Double:
            !number.isNaN && number != 0
        case let number as NSNumber:
            number.doubleValue != 0
        case let text as String:
            text.lowercased() == "yes" || text.lowercased() == "true" || text == "1"
        default:
            false
        }
    }

    /// Reproduces `UserDefaults.integer(forKey:)`.
    ///
    /// A `Bool` reads as `1` or `0`. A `Double` truncates toward zero, so `3.99`
    /// reads as `3` and `-3.99` as `-3`, saturating at the bounds of `Int`. A string
    /// must be an optionally signed run of digits in its entirety after any leading
    /// spaces or tabs, so `"42"` and `" 42"` read as `42` while `"3.99"`, `"42abc"`
    /// and `"42 "` all read as `0`. Dates, arrays, data and a missing key read as
    /// `0`.
    static func integer(from value: Any?) -> Int {
        switch value {
        case let flag as Bool:
            flag ? 1 : 0
        case let number as Int:
            number
        case let number as Double:
            truncating(number)
        case let number as NSNumber:
            number.intValue
        case let text as String:
            integer(fromString: text)
        default:
            0
        }
    }

    /// Reproduces `UserDefaults.double(forKey:)`.
    ///
    /// A `Bool` reads as `1` or `0`. A string contributes its leading numeric run
    /// after any leading spaces or tabs and ignores whatever follows, so `"3.14abc"`
    /// reads as `3.14` and `"42abc"` as `42`. A string with no numeric prefix reads
    /// as `0`, and that includes `"inf"` and `"nan"`, neither of which is treated as
    /// a number. Dates, arrays, data and a missing key read as `0`.
    static func double(from value: Any?) -> Double {
        switch value {
        case let flag as Bool:
            flag ? 1 : 0
        case let number as Int:
            Double(number)
        case let number as Double:
            number
        case let number as NSNumber:
            number.doubleValue
        case let text as String:
            double(fromString: text)
        default:
            0
        }
    }

    /// Reproduces `UserDefaults.string(forKey:)`.
    ///
    /// Numbers are stringified as `NSNumber` stringifies them, which drops a
    /// redundant fractional part, so a stored `3.0` reads as `"3"` rather than
    /// `"3.0"`. A `Bool` reads as `"1"` or `"0"`. Dates, data, arrays and a missing
    /// key read as `nil`.
    static func string(from value: Any?) -> String? {
        switch value {
        case let text as String:
            text
        case let flag as Bool:
            flag ? "1" : "0"
        case let number as Int:
            NSNumber(value: number).stringValue
        case let number as Double:
            NSNumber(value: number).stringValue
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }

    /// Reproduces `UserDefaults.stringArray(forKey:)`.
    ///
    /// Returns the array only when every element is a string. A mixed array or an
    /// array of numbers reads as `nil` rather than as a filtered or empty array.
    static func stringArray(from value: Any?) -> [String]? {
        value as? [String]
    }

    // MARK: - String parsing

    /// Parses a string the way `integer(forKey:)` does: the whole string, after any
    /// leading spaces or tabs, must be an optionally signed run of ASCII digits.
    ///
    /// The result saturates at the bounds of `Int32` rather than `Int`, which is why
    /// a stored `"9223372036854775807"` reads as `2147483647` while the same value
    /// stored as a number reads back whole.
    private static func integer(fromString text: String) -> Int {
        let scanned = text.drop(while: isLeadingSpace)
        var digits = scanned
        var isNegative = false
        if let sign = digits.first, sign == "+" || sign == "-" {
            isNegative = sign == "-"
            digits = digits.dropFirst()
        }
        guard !digits.isEmpty, digits.allSatisfy(isDigit) else {
            return 0
        }
        guard let wide = Int64(scanned) else {
            // Well formed but beyond Int64, such as "9999999999999999999999".
            return isNegative ? Int(Int32.min) : Int(Int32.max)
        }
        return Int(Int32(clamping: wide))
    }

    /// Parses a string the way `double(forKey:)` does: the longest numeric prefix
    /// after any leading spaces or tabs, ignoring any trailing characters.
    ///
    /// An exponent counts only when at least one digit follows it, so `"5e"` reads
    /// as `5` rather than failing outright.
    private static func double(fromString text: String) -> Double {
        var remainder = text.drop(while: isLeadingSpace)
        var numeric = ""

        if let sign = remainder.first, sign == "+" || sign == "-" {
            numeric.append(sign)
            remainder = remainder.dropFirst()
        }

        let wholeDigits = remainder.prefix(while: isDigit)
        numeric += wholeDigits
        remainder = remainder.dropFirst(wholeDigits.count)

        var fractionDigitCount = 0
        if remainder.first == "." {
            let fractionDigits = remainder.dropFirst().prefix(while: isDigit)
            fractionDigitCount = fractionDigits.count
            if fractionDigitCount > 0 {
                numeric += "." + fractionDigits
            }
            remainder = remainder.dropFirst(1 + fractionDigitCount)
        }

        guard wholeDigits.count + fractionDigitCount > 0 else {
            return 0
        }

        if let marker = remainder.first, marker == "e" || marker == "E" {
            var exponent = remainder.dropFirst()
            var exponentSign = ""
            if let sign = exponent.first, sign == "+" || sign == "-" {
                exponentSign = String(sign)
                exponent = exponent.dropFirst()
            }
            let exponentDigits = exponent.prefix(while: isDigit)
            if !exponentDigits.isEmpty {
                numeric += "e" + exponentSign + exponentDigits
            }
        }

        return Double(numeric) ?? 0
    }

    /// Truncates toward zero, saturating rather than trapping on a value too large
    /// for `Int`.
    private static func truncating(_ value: Double) -> Int {
        guard !value.isNaN else { return 0 }
        if value >= Double(Int.max) { return .max }
        if value <= Double(Int.min) { return .min }
        return Int(value)
    }

    /// The only whitespace `UserDefaults` skips before a number in a string.
    private static func isLeadingSpace(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    private static func isDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }
}
