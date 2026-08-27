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
/// The rule is "not equal to zero". Not-a-number and the infinities follow from that
/// same rule and are asserted in `UserDefaultsSpecialValueTests`, which is where all
/// three special values live.
let booleanFromDoubleCases: [Coercion<Double, Bool>] = [
    Coercion(1.5, reads: true),
    Coercion(0.5, reads: true),
    Coercion(0, reads: false)
]

/// Rows for `string` reading a stored `Double`.
///
/// The formatting is `NSNumber`'s, which drops a redundant fractional part and keeps
/// the sign on negative zero. The special values are spelled out rather than
/// formatted, so they are stated in `UserDefaultsSpecialValueTests` instead.
let stringFromDoubleCases: [Coercion<Double, String>] = [
    Coercion(3.14, reads: "3.14"),
    Coercion(100.5, reads: "100.5"),
    Coercion(0.1, reads: "0.1"),
    Coercion(3.0, reads: "3"),
    Coercion(-0.0, reads: "-0"),
    Coercion(1e20, reads: "1e+20"),
    Coercion(1e-20, reads: "9.999999999999999e-21")
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
            store.setString(row.written, forKey: "key")
            #expect(store.bool(forKey: "key") == row.expected)
        }
    }

    @Test("bool reads a stored double",
          arguments: StoreKind.allCases, booleanFromDoubleCases)
    func booleanReadsADouble(kind: StoreKind, row: Coercion<Double, Bool>) throws {
        try withStore(kind) { store in
            store.setDouble(row.written, forKey: "key")
            #expect(store.bool(forKey: "key") == row.expected)
        }
    }

    /// Any non-zero integer is true, negative ones included, so this is not a "is it
    /// exactly one" test.
    @Test("bool reads a stored integer as not equal to zero",
          arguments: StoreKind.allCases, [1, 2, -1, 0])
    func booleanReadsAnInt(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, forKey: "key")
            #expect(store.bool(forKey: "key") == (value != 0))
        }
    }

    @Test("string reads a stored double",
          arguments: StoreKind.allCases, stringFromDoubleCases)
    func stringReadsADouble(kind: StoreKind, row: Coercion<Double, String>) throws {
        try withStore(kind) { store in
            store.setDouble(row.written, forKey: "key")
            #expect(store.string(forKey: "key") == row.expected)
        }
    }

    @Test("string reads a stored integer",
          arguments: StoreKind.allCases, [0, 42, -7, Int.max])
    func stringReadsAnInt(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, forKey: "key")
            #expect(store.string(forKey: "key") == String(value))
        }
    }

    @Test("string reads a stored Boolean as one or zero",
          arguments: StoreKind.allCases, [true, false])
    func stringReadsABool(kind: StoreKind, flag: Bool) throws {
        try withStore(kind) { store in
            store.setBool(flag, forKey: "key")
            #expect(store.string(forKey: "key") == (flag ? "1" : "0"))
        }
    }

    /// A date, an array or a blob has no string reading at all. None is rendered into
    /// a description, so a caller cannot mistake one for stored text.
    @Test("A date, an array or a blob has no string reading",
          arguments: StoreKind.allCases, SeededValue.nonNumericCases)
    func aNonNumericValueHasNoStringReading(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            try seeded.write(into: store, key: "key")
            #expect(store.string(forKey: "key") == nil)
        }
    }

    /// `stringArray` is all or nothing. A mixed array is not filtered down to the
    /// strings it happens to contain, and an array of numbers is not stringified.
    ///
    /// Building the mixed and non-string arrays is what `setPropertyList` is for. The
    /// endpoint it replaced took `Any?`, and this case is the reason the replacement
    /// had to keep accepting a heterogeneous value rather than being retired outright:
    /// a defaults domain is shared, so a value this API did not write can be in it,
    /// and a suite that could not construct one could not check what the readers do
    /// with it.
    @Test("stringArray reads only an array whose elements are all strings",
          arguments: StoreKind.allCases)
    func stringArrayReadsOnlyStrings(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setPropertyList(["a", "b"], forKey: "all-strings")
            store.setPropertyList(["a", 1], forKey: "mixed")
            store.setPropertyList([1, 2], forKey: "numbers")
            store.setPropertyList(.array([.date(sampleDate)]), forKey: "dates")
            store.setString("abc", forKey: "text")

            #expect(store.stringArray(forKey: "all-strings") == ["a", "b"])
            #expect(store.stringArray(forKey: "mixed") == nil)
            #expect(store.stringArray(forKey: "numbers") == nil)
            #expect(store.stringArray(forKey: "dates") == nil)
            #expect(store.stringArray(forKey: "text") == nil)
        }
    }

    /// `date` reads a stored date and nothing else. A number is not taken for a time
    /// interval, which is the coercion a caller is most likely to expect and not get.
    @Test("date reads only a stored date", arguments: StoreKind.allCases)
    func dateReadsOnlyADate(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setDouble(1000, forKey: "number")
            store.setString("2026-08-18", forKey: "text")
            store.setStringArray(["a"], forKey: "list")

            #expect(store.date(forKey: "number") == nil)
            #expect(store.date(forKey: "text") == nil)
            #expect(store.date(forKey: "list") == nil)
        }
    }

    /// Stored data reads as `false` rather than as `nil` or as "there are bytes here,
    /// so yes".
    ///
    /// The string reading is covered for every non-numeric sample by the case above.
    @Test("Stored data has no Boolean reading", arguments: StoreKind.allCases)
    func dataHasNoBooleanReading(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setData(sampleData, forKey: "key")

            #expect(store.bool(forKey: "key") == false)
        }
    }

    /// `url` reads only text that is an absolute URL.
    ///
    /// The rows that matter are the ones `URL(string:)` accepts and this endpoint does
    /// not. That initialiser parses almost anything, percent-encoding what it cannot
    /// use, and returns a relative URL with no scheme; a caller asking a key for a URL
    /// wants one it can open, so a reading with no scheme is not a reading.
    @Test("url reads only text that parses as a URL with a scheme",
          arguments: StoreKind.allCases)
    func urlReadsOnlyAbsoluteURLs(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setString("https://example.com/x", forKey: "absolute")
            store.setString("mailto:someone@example.com", forKey: "mailto")
            store.setString("hello", forKey: "bare-word")
            store.setString("/tmp/path", forKey: "bare-path")
            store.setString("//example.com", forKey: "scheme-relative")
            store.setString("", forKey: "empty")
            store.setInt(42, forKey: "number")
            store.setDate(sampleDate, forKey: "moment")

            #expect(store.url(forKey: "absolute")?.absoluteString == "https://example.com/x")
            #expect(store.url(forKey: "mailto")?.scheme == "mailto")
            #expect(store.url(forKey: "bare-word") == nil)
            #expect(store.url(forKey: "bare-path") == nil)
            #expect(store.url(forKey: "scheme-relative") == nil)
            #expect(store.url(forKey: "empty") == nil)
            #expect(store.url(forKey: "number") == nil)
            #expect(store.url(forKey: "moment") == nil)
        }
    }

    /// `data` reads only stored bytes. A string is not decoded into its UTF-8, which
    /// is the coercion a caller is most likely to expect and not get.
    @Test("data reads only stored bytes", arguments: StoreKind.allCases)
    func dataReadsOnlyBytes(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setString("abc", forKey: "text")
            store.setInt(42, forKey: "number")
            store.setDate(sampleDate, forKey: "moment")
            store.setStringArray(["a"], forKey: "list")

            #expect(store.data(forKey: "text") == nil)
            #expect(store.data(forKey: "number") == nil)
            #expect(store.data(forKey: "moment") == nil)
            #expect(store.data(forKey: "list") == nil)
        }
    }
}
