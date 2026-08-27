//
//  UserDefaultsContractFixtures.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// One row of a coercion table: a value written through the setter for its own type,
/// and what a reader for a different type must return once it is stored.
///
/// `UserDefaults` converts on read rather than returning a default when the stored
/// type differs from the requested one, and the conversions are not the obvious ones.
/// Each row here is the behaviour of live `UserDefaults`, and is asserted against both
/// stores, so the double is held to the same table as production.
struct Coercion<Written: Sendable, Read: Sendable>: Sendable, CustomTestStringConvertible {

    /// The value written through the setter for its own type.
    let written: Written

    /// What the reader under test must return once `written` is stored.
    let expected: Read

    init(_ written: Written, reads expected: Read) {
        self.written = written
        self.expected = expected
    }

    var testDescription: String {
        "\(described(written)) reads as \(described(expected))"
    }
}

/// Renders a table value for a case name, putting quotation marks around a string.
///
/// These tables exist because a stored `"42"` and a stored `42` read back differently,
/// so a case name that printed both as `42` would leave a failure hard to place.
private func described(_ value: Any) -> String {
    if let text = value as? String {
        return "\"\(text)\""
    }
    return String(describing: value)
}

/// Compares a double a reader returned against the value a table expects.
///
/// Not-a-number is never equal to itself, so a plain `==` would fail the rows whose
/// expected result is not-a-number even when the reader returned exactly that. Those
/// rows are real behaviour: a stored not-a-number reads back unchanged through
/// `double`, unlike the string `"nan"`, which reads as zero.
///
/// `actual` is optional because the reader is: `nil` means the key held nothing, which
/// no row here expects, so it is never a match. A row that wants absence says so with
/// `expectAbsent` instead.
func matches(_ actual: Double?, _ expected: Double) -> Bool {
    guard let actual else {
        return false
    }
    if expected.isNaN {
        return actual.isNaN
    }
    return actual == expected
}

/// A URL with a scheme, a host, a path, a query and a fragment, so a round trip that
/// drops any of those parts fails rather than passing on a simpler value.
///
/// A function rather than a stored `let` because `URL(string:)` is failable and this
/// target does not force unwrap. `#require` turns a parse this suite could not make
/// into one clear failure naming the fixture, in the same way the harness handles the
/// failable store initialiser.
func sampleURL(sourceLocation: SourceLocation = #_sourceLocation) throws -> URL {
    try #require(
        URL(string: "https://example.com/a/b?c=d#e"),
        "The sample URL no longer parses.",
        sourceLocation: sourceLocation
    )
}

/// A date whose value survives a property list round trip exactly.
///
/// Property lists store a date as a count of seconds in a `Double`, so a date taken
/// from the clock could lose precision on the way through and turn a storage failure
/// into an indistinguishable rounding failure. This one is exactly representable, so a
/// round-trip failure means the store dropped or altered the value.
let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

/// A short blob whose bytes include a zero and a high byte, so a store that round
/// tripped it through a string encoding would fail rather than pass on ASCII.
let sampleData = Data([0x00, 0x01, 0xFF])

/// One endpoint that puts a value into a store, paired with a sample of the right type.
///
/// Used by the cases that must hold no matter which setter the value arrived through,
/// such as removal clearing the key.
enum SeededValue: String, CaseIterable, Sendable, CustomTestStringConvertible {

    case bool
    case int
    case double
    case string
    case stringArray
    case date
    case data
    case url
    case propertyList

    /// The samples that read as zero through `int` and `double` and as `nil` through
    /// `string`.
    ///
    /// Reading as zero is not on its own enough to belong here. A stored `"abc"` is
    /// zero through both number readers too, but it is still a string, so `string`
    /// returns it rather than `nil` and it stays out of this list.
    ///
    /// `url` stays out for the same reason and it is worth saying why, because the
    /// intuition points the other way: a URL is stored as its `absoluteString`, so the
    /// key holds text and `string` returns that text. `data` is in the list, having
    /// been measured against a real suite: a stored blob has no string reading and no
    /// numeric one.
    static let nonNumericCases: [SeededValue] = [.stringArray, .date, .data]

    var testDescription: String {
        rawValue
    }

    /// Writes this endpoint's sample value under `key`.
    @MainActor
    func write(into store: UserDefaultsClient, key: String) throws {
        switch self {
        case .bool:
            store.setBool(true, forKey: key)
        case .int:
            store.setInt(42, forKey: key)
        case .double:
            store.setDouble(3.5, forKey: key)
        case .string:
            store.setString("abc", forKey: key)
        case .stringArray:
            store.setStringArray(["a", "b"], forKey: key)
        case .date:
            store.setDate(sampleDate, forKey: key)
        case .data:
            store.setData(sampleData, forKey: key)
        case .url:
            store.setURL(try sampleURL(), forKey: key)
        case .propertyList:
            store.setPropertyList(["a": 1, "b": "two"], forKey: key)
        }
    }
}

/// A setter that accepts `nil`, together with a value to seed the key first.
///
/// Live `UserDefaults` treats a `nil` write as a removal rather than storing a
/// placeholder that later reads as present, and every conformer must do the same.
enum NilCapableSetter: String, CaseIterable, Sendable, CustomTestStringConvertible {

    case string
    case stringArray
    case date
    case data
    case url
    case propertyList

    var testDescription: String {
        rawValue
    }

    /// Writes a non-nil value, so there is something for the `nil` write to remove.
    @MainActor
    func seed(_ store: UserDefaultsClient, key: String) throws {
        switch self {
        case .string:
            store.setString("abc", forKey: key)
        case .stringArray:
            store.setStringArray(["a", "b"], forKey: key)
        case .date:
            store.setDate(sampleDate, forKey: key)
        case .data:
            store.setData(sampleData, forKey: key)
        case .url:
            store.setURL(try sampleURL(), forKey: key)
        case .propertyList:
            store.setPropertyList("abc", forKey: key)
        }
    }

    /// Writes `nil` through the same setter that seeded the key.
    @MainActor
    func writeNil(_ store: UserDefaultsClient, key: String) {
        switch self {
        case .string:
            store.setString(nil, forKey: key)
        case .stringArray:
            store.setStringArray(nil, forKey: key)
        case .date:
            store.setDate(nil, forKey: key)
        case .data:
            store.setData(nil, forKey: key)
        case .url:
            store.setURL(nil, forKey: key)
        case .propertyList:
            store.setPropertyList(nil, forKey: key)
        }
    }
}
