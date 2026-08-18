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
func matches(_ actual: Double, _ expected: Double) -> Bool {
    if expected.isNaN {
        return actual.isNaN
    }
    return actual == expected
}

/// A date whose value survives a property list round trip exactly.
///
/// Property lists store a date as a count of seconds in a `Double`, so a date taken
/// from the clock could lose precision on the way through and turn a storage failure
/// into an indistinguishable rounding failure. This one is exactly representable, so a
/// round-trip failure means the store dropped or altered the value.
let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

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
    case object

    /// The samples that read as zero through `int` and `double` and as `nil` through
    /// `string`.
    ///
    /// Reading as zero is not on its own enough to belong here. A stored `"abc"` is
    /// zero through both number readers too, but it is still a string, so `string`
    /// returns it rather than `nil` and it stays out of this list.
    static let nonNumericCases: [SeededValue] = [.stringArray, .date]

    var testDescription: String {
        rawValue
    }

    /// Writes this endpoint's sample value under `key`.
    @MainActor
    func write(into store: any UserDefaultsStoreProtocol, key: String) {
        switch self {
        case .bool:
            store.setBool(true, key)
        case .int:
            store.setInt(42, key)
        case .double:
            store.setDouble(3.5, key)
        case .string:
            store.setString("abc", key)
        case .stringArray:
            store.setStringArray(["a", "b"], key)
        case .date:
            store.setDate(sampleDate, key)
        case .object:
            store.setObject("abc", key)
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
    case object

    var testDescription: String {
        rawValue
    }

    /// Writes a non-nil value, so there is something for the `nil` write to remove.
    @MainActor
    func seed(_ store: any UserDefaultsStoreProtocol, key: String) {
        switch self {
        case .string:
            store.setString("abc", key)
        case .stringArray:
            store.setStringArray(["a", "b"], key)
        case .date:
            store.setDate(sampleDate, key)
        case .object:
            store.setObject("abc", key)
        }
    }

    /// Writes `nil` through the same setter that seeded the key.
    @MainActor
    func writeNil(_ store: any UserDefaultsStoreProtocol, key: String) {
        switch self {
        case .string:
            store.setString(nil, key)
        case .stringArray:
            store.setStringArray(nil, key)
        case .date:
            store.setDate(nil, key)
        case .object:
            store.setObject(nil, key)
        }
    }
}
