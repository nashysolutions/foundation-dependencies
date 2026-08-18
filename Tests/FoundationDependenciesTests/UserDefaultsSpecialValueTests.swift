//
//  UserDefaultsSpecialValueTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// One of the three double values whose readings cannot be guessed.
///
/// They get a suite of their own rather than a row buried in each reader's table,
/// because they are where this package has actually been wrong. The boolean reader
/// once carried a not-a-number guard that was added defensively and never measured,
/// and it made the double disagree with production on exactly the input it was meant
/// to protect.
enum SpecialDouble: String, CaseIterable, Sendable, CustomTestStringConvertible {

    case notANumber
    case infinity
    case negativeInfinity

    var value: Double {
        switch self {
        case .notANumber: .nan
        case .infinity: .infinity
        case .negativeInfinity: -.infinity
        }
    }

    var testDescription: String {
        rawValue
    }
}

/// What every conformer must return from each reader for a stored not-a-number,
/// infinity, or negative infinity.
///
/// Every reader gets a case, so none of the three can be covered for some endpoints
/// and quietly missed for others.
@Suite("Not-a-number and infinity")
@MainActor
struct UserDefaultsSpecialValueTests {

    /// All three are true, and not-a-number is the one worth stating out loud: the
    /// rule is "not equal to zero", and not-a-number compares unequal to everything,
    /// zero included. Reading it as `false` looks like the careful answer and is the
    /// wrong one.
    @Test("bool reads every special value as true",
          arguments: StoreKind.allCases, SpecialDouble.allCases)
    func booleanReadsASpecialValue(kind: StoreKind, special: SpecialDouble) throws {
        try withStore(kind) { store in
            store.setDouble(special.value, "key")
            #expect(store.bool("key") == true)
        }
    }

    /// The infinities saturate at the bounds of `Int`, and not-a-number is zero. The
    /// zero is load bearing rather than merely measured: `Int(Double.nan)` traps in
    /// Swift, so a reader that reached the conversion would crash rather than
    /// disagree.
    @Test("int saturates at the bounds for the infinities and reads not-a-number as zero",
          arguments: StoreKind.allCases, SpecialDouble.allCases)
    func integerReadsASpecialValue(kind: StoreKind, special: SpecialDouble) throws {
        let expected: Int = switch special {
        case .notANumber: 0
        case .infinity: .max
        case .negativeInfinity: .min
        }

        try withStore(kind) { store in
            store.setDouble(special.value, "key")
            #expect(store.int("key") == expected)
        }
    }

    @Test("double reads every special value back unchanged",
          arguments: StoreKind.allCases, SpecialDouble.allCases)
    func doubleReadsASpecialValue(kind: StoreKind, special: SpecialDouble) throws {
        try withStore(kind) { store in
            store.setDouble(special.value, "key")
            #expect(matches(store.double("key"), special.value))
        }
    }

    /// Spelled out in full and in lower case, with the sign kept on negative infinity.
    @Test("string spells every special value out",
          arguments: StoreKind.allCases, SpecialDouble.allCases)
    func stringReadsASpecialValue(kind: StoreKind, special: SpecialDouble) throws {
        let expected = switch special {
        case SpecialDouble.notANumber: "nan"
        case .infinity: "inf"
        case .negativeInfinity: "-inf"
        }

        try withStore(kind) { store in
            store.setDouble(special.value, "key")
            #expect(store.string("key") == expected)
        }
    }

    @Test("A special value has no array reading and no date reading",
          arguments: StoreKind.allCases, SpecialDouble.allCases)
    func aSpecialValueHasNoArrayOrDateReading(
        kind: StoreKind,
        special: SpecialDouble
    ) throws {
        try withStore(kind) { store in
            store.setDouble(special.value, "key")

            #expect(store.stringArray("key") == nil)
            #expect(store.date("key") == nil)
        }
    }

    /// The contrast that stops the rows above from being read as "these names mean
    /// these values".
    ///
    /// Stored as text, the names are not numbers at all. `"inf"` reads as zero, not
    /// infinity, and `"nan"` reads as zero rather than as not-a-number, which is how
    /// these readers differ from `strtod`. So a stored double and a stored string
    /// spelling the same thing read back differently through every number reader.
    @Test("The spelled out names are not read as the values they name",
          arguments: StoreKind.allCases, ["inf", "-inf", "nan", "infinity", "INF", "NaN"])
    func spelledOutNamesAreNotNumbers(kind: StoreKind, text: String) throws {
        try withStore(kind) { store in
            store.setString(text, "key")

            #expect(store.int("key") == 0)
            #expect(store.double("key") == 0)
            #expect(store.bool("key") == false)
        }
    }
}
