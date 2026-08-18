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
@Suite("Absence and removal")
@MainActor
struct UserDefaultsStoreAbsenceTests {

    @Test("An absent key reads as the documented default", arguments: StoreKind.allCases)
    func absentKeyReadsAsTheDocumentedDefault(kind: StoreKind) throws {
        try withStore(kind) { store in
            expectAbsent(store, key: "never-written")
        }
    }

    @Test("removeObject clears the key whichever setter wrote it",
          arguments: StoreKind.allCases, SeededValue.allCases)
    func removeObjectClearsTheKey(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            seeded.write(into: store, key: "key")
            #expect(store.object("key") != nil)

            store.removeObject("key")

            expectAbsent(store, key: "key")
        }
    }

    @Test("Writing nil removes the key rather than storing a placeholder",
          arguments: StoreKind.allCases, NilCapableSetter.allCases)
    func nilWriteRemovesTheKey(kind: StoreKind, setter: NilCapableSetter) throws {
        try withStore(kind) { store in
            setter.seed(store, key: "key")
            #expect(store.object("key") != nil)

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
            store.setString("", "key")

            #expect(store.object("key") != nil)
            #expect(store.string("key") == "")
        }
    }

    /// The same applies to an empty array: writing one is not a way to remove the key.
    @Test("An empty string array is stored rather than treated as a removal",
          arguments: StoreKind.allCases)
    func emptyStringArrayIsStored(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setStringArray([], "key")

            #expect(store.object("key") != nil)
            #expect(store.stringArray("key") == [])
        }
    }

    @Test("Removing a key that was never written is harmless",
          arguments: StoreKind.allCases)
    func removingAnAbsentKeyIsHarmless(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.removeObject("never-written")

            expectAbsent(store, key: "never-written")
        }
    }

    @Test("Removing a key twice is harmless", arguments: StoreKind.allCases)
    func removingTwiceIsHarmless(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, "key")

            store.removeObject("key")
            store.removeObject("key")

            expectAbsent(store, key: "key")
        }
    }

    /// A key can come back after being cleared. Removal is not a tombstone.
    @Test("A key can be written again after removal", arguments: StoreKind.allCases)
    func aRemovedKeyCanBeWrittenAgain(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, "key")
            store.removeObject("key")
            store.setInt(7, "key")

            #expect(store.int("key") == 7)
        }
    }
}
