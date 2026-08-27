//
//  UserDefaultsStoreAbsenceTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// What every conformer must do about a key that is not there, and about the two ways
/// of making a key stop being there.
///
/// A key never written, a key removed, and a key cleared by writing `nil` must all be
/// indistinguishable afterwards. `expectAbsent` states the readings once so the three
/// cannot drift into disagreeing.
///
/// Every reading is `nil`, and `contains` is `false`. Before the read surface became
/// optional, `bool`, `int` and `double` answered `false` and `0` here, which a key
/// holding a stored `false` or `0` also answered, so this suite could not tell the two
/// situations apart. `presentKeysHaveScalarReadings` is the other side of that: a key
/// holding anything at all still has a reading through those three, so `nil` means
/// absence and only absence.
@Suite("Absence and removal")
@MainActor
struct UserDefaultsStoreAbsenceTests {

    @Test("An absent key reads as the documented default", arguments: StoreKind.allCases)
    func absentKeyReadsAsTheDocumentedDefault(kind: StoreKind) throws {
        try withStore(kind) { store in
            expectAbsent(store, key: "never-written")
        }
    }

    @Test("removeValue clears the key whichever setter wrote it",
          arguments: StoreKind.allCases, SeededValue.allCases)
    func removeValueClearsTheKey(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            try seeded.write(into: store, key: "key")
            #expect(store.contains(key: "key"))

            store.removeValue(forKey: "key")

            expectAbsent(store, key: "key")
        }
    }

    /// The other half of what `nil` has to mean.
    ///
    /// A reading of `nil` from `bool`, `int` or `double` is the signal for absence, so
    /// a key holding a value must never produce one, however little numeric sense the
    /// value makes. A date, an array and a blob are all in `SeededValue`, and live
    /// `UserDefaults` gives each of them a reading rather than refusing.
    @Test("A key that holds a value has a reading through every scalar reader",
          arguments: StoreKind.allCases, SeededValue.allCases)
    func presentKeysHaveScalarReadings(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            try seeded.write(into: store, key: "key")

            expectScalarReadings(store, key: "key")
        }
    }

    /// The case the redesign exists for.
    ///
    /// A stored `false` and a stored `0` are the two values the old non-optional
    /// readers could not distinguish from a key that was never written. Both are
    /// present, and both read back as themselves.
    @Test("A stored false and a stored zero are distinguishable from absence",
          arguments: StoreKind.allCases)
    func storedFalseAndZeroAreNotAbsence(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setBool(false, forKey: "flag")
            store.setInt(0, forKey: "count")
            store.setDouble(0, forKey: "measure")

            #expect(store.bool(forKey: "flag") == false)
            #expect(store.int(forKey: "count") == 0)
            #expect(store.double(forKey: "measure") == 0)

            expectAbsent(store, key: "never-written")
        }
    }

    @Test("Writing nil removes the key rather than storing a placeholder",
          arguments: StoreKind.allCases, NilCapableSetter.allCases)
    func nilWriteRemovesTheKey(kind: StoreKind, setter: NilCapableSetter) throws {
        try withStore(kind) { store in
            try setter.seed(store, key: "key")
            #expect(store.contains(key: "key"))

            setter.writeNil(store, key: "key")

            expectAbsent(store, key: "key")
        }
    }

    /// The empty string is the value most likely to be confused with a removal, and it
    /// is not one. It is stored, and the key stays present.
    @Test("An empty string is stored rather than treated as a removal",
          arguments: StoreKind.allCases)
    func emptyStringIsStored(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setString("", forKey: "key")

            #expect(store.contains(key: "key"))
            #expect(store.string(forKey: "key") == "")
        }
    }

    /// The same applies to an empty array: writing one is not a way to remove the key.
    @Test("An empty string array is stored rather than treated as a removal",
          arguments: StoreKind.allCases)
    func emptyStringArrayIsStored(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setStringArray([], forKey: "key")

            #expect(store.contains(key: "key"))
            #expect(store.stringArray(forKey: "key") == [])
        }
    }

    @Test("Removing a key that was never written is harmless",
          arguments: StoreKind.allCases)
    func removingAnAbsentKeyIsHarmless(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.removeValue(forKey: "never-written")

            expectAbsent(store, key: "never-written")
        }
    }

    @Test("Removing a key twice is harmless", arguments: StoreKind.allCases)
    func removingTwiceIsHarmless(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, forKey: "key")

            store.removeValue(forKey: "key")
            store.removeValue(forKey: "key")

            expectAbsent(store, key: "key")
        }
    }

    /// A key can come back after being cleared. Removal is not a tombstone.
    @Test("A key can be written again after removal", arguments: StoreKind.allCases)
    func aRemovedKeyCanBeWrittenAgain(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, forKey: "key")
            store.removeValue(forKey: "key")
            store.setInt(7, forKey: "key")

            #expect(store.int(forKey: "key") == 7)
        }
    }
}
