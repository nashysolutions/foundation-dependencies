//
//  UserDefaultsStoreRoundTripTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// What every conformer must do when a value is read back through the reader that
/// matches the setter it was written with.
///
/// This is the part of the contract with no surprises in it. The coercion suites cover
/// what happens when the reader and the setter disagree about the type.
@Suite("Round trips")
@MainActor
struct UserDefaultsStoreRoundTripTests {

    @Test("A Boolean reads back as written", arguments: StoreKind.allCases, [true, false])
    func boolRoundTrips(kind: StoreKind, value: Bool) throws {
        try withStore(kind) { store in
            store.setBool(value, "key")
            #expect(store.bool("key") == value)
        }
    }

    @Test(
        "An integer reads back as written",
        arguments: StoreKind.allCases, [0, 42, -7, Int.min, Int.max]
    )
    func intRoundTrips(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, "key")
            #expect(store.int("key") == value)
        }
    }

    /// Infinity and not-a-number are included because they are the values a store is
    /// most likely to mangle, and because they read back unchanged here while the
    /// strings `"inf"` and `"nan"` do not.
    @Test(
        "A double reads back as written",
        arguments: StoreKind.allCases, [0, 3.14, -1.5, .infinity, -.infinity, .nan]
    )
    func doubleRoundTrips(kind: StoreKind, value: Double) throws {
        try withStore(kind) { store in
            store.setDouble(value, "key")
            #expect(matches(store.double("key"), value))
        }
    }

    @Test(
        "A string reads back as written",
        arguments: StoreKind.allCases, ["abc", "", "  ", "42", "🎉"]
    )
    func stringRoundTrips(kind: StoreKind, value: String) throws {
        try withStore(kind) { store in
            store.setString(value, "key")
            #expect(store.string("key") == value)
        }
    }

    @Test(
        "A string array reads back as written",
        arguments: StoreKind.allCases, [["a", "b"], [], ["", "x"]]
    )
    func stringArrayRoundTrips(kind: StoreKind, value: [String]) throws {
        try withStore(kind) { store in
            store.setStringArray(value, "key")
            #expect(store.stringArray("key") == value)
        }
    }

    @Test("A date reads back as written", arguments: StoreKind.allCases)
    func dateRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setDate(sampleDate, "key")
            #expect(store.date("key") == sampleDate)
        }
    }

    /// `setObject` is the untyped way in, and every property list type must arrive
    /// intact enough for the matching typed reader to find it.
    @Test("A property list value written through setObject reaches its typed reader",
          arguments: StoreKind.allCases)
    func objectWritesReachTheTypedReaders(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setObject("abc", "text")
            store.setObject(42, "number")
            store.setObject(3.5, "fraction")
            store.setObject(true, "flag")
            store.setObject(sampleDate, "moment")
            store.setObject(["a", "b"], "list")

            #expect(store.string("text") == "abc")
            #expect(store.int("number") == 42)
            #expect(store.double("fraction") == 3.5)
            #expect(store.bool("flag") == true)
            #expect(store.date("moment") == sampleDate)
            #expect(store.stringArray("list") == ["a", "b"])
        }
    }

    /// The contract on `object` is presence, not type.
    ///
    /// Live `UserDefaults` normalises a value into its Foundation counterpart on the
    /// way in, so a stored `Int` comes back out of `object` as an `NSNumber` there and
    /// as an `Int` from the in-memory store. That divergence is documented on
    /// `UserDefaultsTestStore` and is deliberately not asserted either way here: an
    /// assertion pinning one of the two answers would be pinning an implementation
    /// detail the protocol does not promise. What both must agree on is whether the
    /// key is there at all.
    @Test("Any write makes the key present",
          arguments: StoreKind.allCases, SeededValue.allCases)
    func aWrittenKeyIsPresent(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            seeded.write(into: store, key: "key")
            #expect(store.object("key") != nil)
        }
    }

    @Test("A later write replaces an earlier one, including across types",
          arguments: StoreKind.allCases)
    func lastWriteWins(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, "key")
            #expect(store.int("key") == 42)

            store.setString("abc", "key")
            #expect(store.string("key") == "abc")
            #expect(store.int("key") == 0)
        }
    }

    @Test("Keys do not interfere with each other", arguments: StoreKind.allCases)
    func keysAreIndependent(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(1, "first")
            store.setInt(2, "second")

            store.removeObject("first")

            #expect(store.int("first") == 0)
            #expect(store.int("second") == 2)
        }
    }
}
