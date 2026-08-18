//
//  LiveUserDefaultsSemantics.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// The type coercions live `UserDefaults` applies when the stored value is not
/// already the type being read.
///
/// `UserDefaultsTestStore` reads through these so that a test passing against the
/// double would also pass against production. Each rule was measured against a real
/// `UserDefaults` suite rather than inferred from the documentation, which says only
/// that values are converted.
///
/// Several of the measured rules contradict the obvious guess, so treat this type as
/// the authoritative statement of them:
///
/// - The string readers do not agree with each other. `integer(from:)` demands a
///   whole-string match while `double(from:)` takes a numeric prefix, so `"42abc"`
///   reads as `0` through one and `42.0` through the other.
/// - `integer(from:)` is 32-bit when reading a string and 64-bit otherwise, so a
///   string can saturate where the same value stored as a number does not.
/// - `boolean(from:)` accepts far fewer spellings than `NSString.boolValue` does.
///   `"2"` and `"y"` are both `false` here and both `true` through that property.
/// - Not-a-number is `true` when read as a boolean, because the rule is "not equal
///   to zero" and not-a-number compares unequal to everything.
enum LiveUserDefaultsSemantics {

    /// Reproduces `UserDefaults.bool(forKey:)`.
    ///
    /// A number is `true` when it is not zero, so `2`, `-1` and `0.5` are all `true`,
    /// as are infinity and not-a-number. A string is `true` only when it reads as
    /// `"yes"` or `"true"` in any casing, or is exactly `"1"`; `"2"`, `"01"`, `" 1"`
    /// and `"y"` are all `false`. Dates, arrays, data and a missing key are `false`.
    static func boolean(from value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            flag
        case let number as Int:
            number != 0
        case let number as Double:
            number != 0
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
    /// reads as `3` and `-3.99` as `-3`, saturating at the bounds of `Int`, which
    /// makes infinity read as `Int.max` and negative infinity as `Int.min`.
    /// Not-a-number reads as `0`. A string must be an optionally signed run of digits
    /// in its entirety after any leading spaces or tabs, so `"42"` and `" 42"` read as
    /// `42` while `"3.99"`, `"42abc"` and `"42 "` all read as `0`. Dates, arrays, data
    /// and a missing key read as `0`.
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
    /// reads as `3.14` and `"42abc"` as `42`. A string with no numeric prefix reads as
    /// `0`, and that includes `"inf"` and `"nan"`, neither of which is treated as a
    /// number when spelled out. A stored `Double` keeps whatever it is, infinity and
    /// not-a-number included. Dates, arrays, data and a missing key read as `0`.
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
    /// `"3.0"`, and gives `"inf"` and `"nan"` for the two special values. A `Bool`
    /// reads as `"1"` or `"0"`. Dates, data, arrays and a missing key read as `nil`.
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
    /// An exponent counts only when at least one digit follows it, so `"5e"` reads as
    /// `5` rather than failing outright.
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
    ///
    /// Not-a-number is returned as `0` to match what `integer(forKey:)` reads back
    /// for it. The check is also load bearing on its own: `Int(Double.nan)` traps, so
    /// removing it would crash rather than merely disagree.
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
