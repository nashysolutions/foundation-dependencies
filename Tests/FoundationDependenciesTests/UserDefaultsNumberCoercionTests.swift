//
//  UserDefaultsNumberCoercionTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// Rows for `int` reading a stored `String`.
///
/// The whole string, after any leading spaces or tabs, has to be an optionally signed
/// run of digits. Two rows are the ones that catch people out: `"3.99"` reads as `0`
/// rather than `3`, and the string path saturates at 32 bits, so a value that reads
/// back whole when stored as a number does not when stored as text.
let integerFromStringCases: [Coercion<String, Int>] = [
    Coercion("42", reads: 42),
    Coercion(" 42", reads: 42),
    Coercion("\t42", reads: 42),
    Coercion("+42", reads: 42),
    Coercion("042", reads: 42),
    Coercion("-7", reads: -7),
    Coercion("42 ", reads: 0),
    Coercion("42abc", reads: 0),
    Coercion("abc42", reads: 0),
    Coercion("4 2", reads: 0),
    Coercion("3.99", reads: 0),
    Coercion("1e3", reads: 0),
    Coercion("0x1A", reads: 0),
    Coercion("abc", reads: 0),
    Coercion("", reads: 0),
    Coercion("9223372036854775807", reads: 2_147_483_647),
    Coercion("2147483648", reads: 2_147_483_647),
    Coercion("-2147483649", reads: -2_147_483_648)
]

/// Rows for `int` reading a stored `Double`.
///
/// The value truncates toward zero and saturates at the bounds of `Int` rather than
/// wrapping or trapping. Not-a-number is the row worth keeping: `Int(Double.nan)`
/// traps in Swift, so a store that reached it would crash rather than disagree.
let integerFromDoubleCases: [Coercion<Double, Int>] = [
    Coercion(3.99, reads: 3),
    Coercion(-3.99, reads: -3),
    Coercion(2.9, reads: 2),
    Coercion(-2.9, reads: -2),
    Coercion(1e18, reads: 1_000_000_000_000_000_000),
    Coercion(1e30, reads: .max),
    Coercion(.infinity, reads: .max),
    Coercion(-.infinity, reads: .min),
    Coercion(.nan, reads: 0)
]

/// Rows for `double` reading a stored `String`.
///
/// This reader takes the leading numeric run and ignores whatever follows, which is
/// where it parts company with `int`: `"42abc"` reads as `42` here and as `0` there.
/// The spelled-out `"inf"` and `"nan"` are not treated as numbers, so both read as
/// zero, unlike the stored `Double` values of the same names.
let doubleFromStringCases: [Coercion<String, Double>] = [
    Coercion("3.14", reads: 3.14),
    Coercion("42", reads: 42),
    Coercion("-3.5", reads: -3.5),
    Coercion("+3.5", reads: 3.5),
    Coercion("3.14abc", reads: 3.14),
    Coercion("42abc", reads: 42),
    Coercion("  -3.5xyz", reads: -3.5),
    Coercion(".5", reads: 0.5),
    Coercion("3.", reads: 3),
    Coercion("1e3", reads: 1000),
    Coercion("1E3", reads: 1000),
    Coercion("5e", reads: 5),
    Coercion("5e+", reads: 5),
    Coercion("inf", reads: 0),
    Coercion("nan", reads: 0),
    Coercion("0x1A", reads: 0),
    Coercion("--3", reads: 0),
    Coercion("abc", reads: 0),
    Coercion("", reads: 0)
]

/// What every conformer must return from `int` and `double` when the stored value is
/// some other type.
@Suite("Number coercion")
@MainActor
struct UserDefaultsNumberCoercionTests {

    @Test("int reads a stored string",
          arguments: StoreKind.allCases, integerFromStringCases)
    func integerReadsAString(kind: StoreKind, row: Coercion<String, Int>) throws {
        try withStore(kind) { store in
            store.setString(row.written, "key")
            #expect(store.int("key") == row.expected)
        }
    }

    @Test("int reads a stored double",
          arguments: StoreKind.allCases, integerFromDoubleCases)
    func integerReadsADouble(kind: StoreKind, row: Coercion<Double, Int>) throws {
        try withStore(kind) { store in
            store.setDouble(row.written, "key")
            #expect(store.int("key") == row.expected)
        }
    }

    @Test("int reads a stored Boolean as one or zero",
          arguments: StoreKind.allCases, [true, false])
    func integerReadsABool(kind: StoreKind, flag: Bool) throws {
        try withStore(kind) { store in
            store.setBool(flag, "key")
            #expect(store.int("key") == (flag ? 1 : 0))
        }
    }

    @Test("double reads a stored string",
          arguments: StoreKind.allCases, doubleFromStringCases)
    func doubleReadsAString(kind: StoreKind, row: Coercion<String, Double>) throws {
        try withStore(kind) { store in
            store.setString(row.written, "key")
            #expect(matches(store.double("key"), row.expected))
        }
    }

    @Test("double reads a stored integer", arguments: StoreKind.allCases, [0, 42, -7])
    func doubleReadsAnInt(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, "key")
            #expect(store.double("key") == Double(value))
        }
    }

    @Test("double reads a stored Boolean as one or zero",
          arguments: StoreKind.allCases, [true, false])
    func doubleReadsABool(kind: StoreKind, flag: Bool) throws {
        try withStore(kind) { store in
            store.setBool(flag, "key")
            #expect(store.double("key") == (flag ? 1 : 0))
        }
    }

    /// A value with no numeric reading at all is zero through both readers, rather
    /// than an error or a hash of the bytes.
    @Test("A value that is not a number reads as zero",
          arguments: StoreKind.allCases, SeededValue.nonNumericCases)
    func aNonNumericValueReadsAsZero(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            seeded.write(into: store, key: "key")

            #expect(store.int("key") == 0)
            #expect(store.double("key") == 0)
        }
    }

    @Test("Stored data reads as zero", arguments: StoreKind.allCases)
    func dataReadsAsZero(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setObject(Data([1, 2, 3]), "key")

            #expect(store.int("key") == 0)
            #expect(store.double("key") == 0)
        }
    }
}
