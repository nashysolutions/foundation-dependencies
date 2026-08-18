//
//  UserDefaultsTextCoercionTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// Rows for `bool` reading a stored `String`.
///
/// Far fewer spellings count than `NSString.boolValue` accepts, and the disagreement
/// is the point of the table. `"y"` and `"t"` are false here and true through that
/// property, and `"2"` is false even though the number `2` is true. Nothing is
/// trimmed, so `" 1"` and `"1 "` are both false.
let booleanFromStringCases: [Coercion<String, Bool>] = [
    Coercion("YES", reads: true),
    Coercion("yes", reads: true),
    Coercion("Yes", reads: true),
    Coercion("yEs", reads: true),
    Coercion("true", reads: true),
    Coercion("TRUE", reads: true),
    Coercion("True", reads: true),
    Coercion("TrUe", reads: true),
    Coercion("1", reads: true),
    Coercion("2", reads: false),
    Coercion("-1", reads: false),
    Coercion("0.5", reads: false),
    Coercion("y", reads: false),
    Coercion("Y", reads: false),
    Coercion("t", reads: false),
    Coercion("T", reads: false),
    Coercion("01", reads: false),
    Coercion(" 1", reads: false),
    Coercion("1 ", reads: false),
    Coercion("1.0", reads: false),
    Coercion("truex", reads: false),
    Coercion("yesx", reads: false),
    Coercion("1x", reads: false),
    Coercion("YESS", reads: false),
    Coercion("0", reads: false),
    Coercion("NO", reads: false),
    Coercion("no", reads: false),
    Coercion("false", reads: false),
    Coercion("abc", reads: false),
    Coercion("", reads: false)
]

/// Rows for `bool` reading a stored `Double`.
///
/// The rule is "not equal to zero", which is why not-a-number is true: it compares
/// unequal to everything, zero included.
let booleanFromDoubleCases: [Coercion<Double, Bool>] = [
    Coercion(1.5, reads: true),
    Coercion(0.5, reads: true),
    Coercion(0, reads: false),
    Coercion(.nan, reads: true),
    Coercion(.infinity, reads: true),
    Coercion(-.infinity, reads: true)
]

/// Rows for `string` reading a stored `Double`.
///
/// The formatting is `NSNumber`'s, which drops a redundant fractional part, keeps the
/// sign on negative zero, and spells the two special values out in full.
let stringFromDoubleCases: [Coercion<Double, String>] = [
    Coercion(3.14, reads: "3.14"),
    Coercion(100.5, reads: "100.5"),
    Coercion(0.1, reads: "0.1"),
    Coercion(3.0, reads: "3"),
    Coercion(-0.0, reads: "-0"),
    Coercion(1e20, reads: "1e+20"),
    Coercion(1e-20, reads: "9.999999999999999e-21"),
    Coercion(.nan, reads: "nan"),
    Coercion(.infinity, reads: "inf")
]

/// What every conformer must return from `bool`, `string`, `stringArray` and `date`
/// when the stored value is some other type.
@Suite("Text and container coercion")
@MainActor
struct UserDefaultsTextCoercionTests {

    @Test("bool reads a stored string",
          arguments: StoreKind.allCases, booleanFromStringCases)
    func booleanReadsAString(kind: StoreKind, row: Coercion<String, Bool>) throws {
        try withStore(kind) { store in
            store.setString(row.written, "key")
            #expect(store.bool("key") == row.expected)
        }
    }

    @Test("bool reads a stored double",
          arguments: StoreKind.allCases, booleanFromDoubleCases)
    func booleanReadsADouble(kind: StoreKind, row: Coercion<Double, Bool>) throws {
        try withStore(kind) { store in
            store.setDouble(row.written, "key")
            #expect(store.bool("key") == row.expected)
        }
    }

    /// Any non-zero integer is true, negative ones included, so this is not a "is it
    /// exactly one" test.
    @Test("bool reads a stored integer as not equal to zero",
          arguments: StoreKind.allCases, [1, 2, -1, 0])
    func booleanReadsAnInt(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, "key")
            #expect(store.bool("key") == (value != 0))
        }
    }

    @Test("string reads a stored double",
          arguments: StoreKind.allCases, stringFromDoubleCases)
    func stringReadsADouble(kind: StoreKind, row: Coercion<Double, String>) throws {
        try withStore(kind) { store in
            store.setDouble(row.written, "key")
            #expect(store.string("key") == row.expected)
        }
    }

    @Test("string reads a stored integer",
          arguments: StoreKind.allCases, [0, 42, -7, Int.max])
    func stringReadsAnInt(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, "key")
            #expect(store.string("key") == String(value))
        }
    }

    @Test("string reads a stored Boolean as one or zero",
          arguments: StoreKind.allCases, [true, false])
    func stringReadsABool(kind: StoreKind, flag: Bool) throws {
        try withStore(kind) { store in
            store.setBool(flag, "key")
            #expect(store.string("key") == (flag ? "1" : "0"))
        }
    }

    /// A date or an array has no string reading at all. Neither is rendered into a
    /// description, so a caller cannot mistake one for stored text.
    @Test("A date or an array has no string reading",
          arguments: StoreKind.allCases, SeededValue.nonNumericCases)
    func aDateOrArrayHasNoStringReading(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            seeded.write(into: store, key: "key")
            #expect(store.string("key") == nil)
        }
    }

    /// `stringArray` is all or nothing. A mixed array is not filtered down to the
    /// strings it happens to contain, and an array of numbers is not stringified.
    @Test("stringArray reads only an array whose elements are all strings",
          arguments: StoreKind.allCases)
    func stringArrayReadsOnlyStrings(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setObject(["a", "b"] as [Any], "all-strings")
            store.setObject(["a", 1] as [Any], "mixed")
            store.setObject([1, 2], "numbers")
            store.setObject([sampleDate], "dates")
            store.setString("abc", "text")

            #expect(store.stringArray("all-strings") == ["a", "b"])
            #expect(store.stringArray("mixed") == nil)
            #expect(store.stringArray("numbers") == nil)
            #expect(store.stringArray("dates") == nil)
            #expect(store.stringArray("text") == nil)
        }
    }

    /// `date` reads a stored date and nothing else. A number is not taken for a time
    /// interval, which is the coercion a caller is most likely to expect and not get.
    @Test("date reads only a stored date", arguments: StoreKind.allCases)
    func dateReadsOnlyADate(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setDouble(1000, "number")
            store.setString("2026-08-18", "text")
            store.setStringArray(["a"], "list")

            #expect(store.date("number") == nil)
            #expect(store.date("text") == nil)
            #expect(store.date("list") == nil)
        }
    }

    @Test("Stored data has no Boolean or string reading", arguments: StoreKind.allCases)
    func dataHasNoBooleanOrStringReading(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setObject(Data([1, 2, 3]), "key")

            #expect(store.bool("key") == false)
            #expect(store.string("key") == nil)
        }
    }
}
