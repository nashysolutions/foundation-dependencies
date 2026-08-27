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
            store.setBool(value, forKey: "key")
            #expect(store.bool(forKey: "key") == value)
        }
    }

    @Test(
        "An integer reads back as written",
        arguments: StoreKind.allCases, [0, 42, -7, Int.min, Int.max]
    )
    func intRoundTrips(kind: StoreKind, value: Int) throws {
        try withStore(kind) { store in
            store.setInt(value, forKey: "key")
            #expect(store.int(forKey: "key") == value)
        }
    }

    /// Not-a-number and the infinities also round trip unchanged, but they are
    /// asserted in `UserDefaultsSpecialValueTests` along with every other reader's
    /// answer for them, rather than here.
    @Test(
        "A double reads back as written",
        arguments: StoreKind.allCases, [0, 3.14, -1.5]
    )
    func doubleRoundTrips(kind: StoreKind, value: Double) throws {
        try withStore(kind) { store in
            store.setDouble(value, forKey: "key")
            #expect(matches(store.double(forKey: "key"), value))
        }
    }

    @Test(
        "A string reads back as written",
        arguments: StoreKind.allCases, ["abc", "", "  ", "42", "🎉"]
    )
    func stringRoundTrips(kind: StoreKind, value: String) throws {
        try withStore(kind) { store in
            store.setString(value, forKey: "key")
            #expect(store.string(forKey: "key") == value)
        }
    }

    @Test(
        "A string array reads back as written",
        arguments: StoreKind.allCases, [["a", "b"], [], ["", "x"]]
    )
    func stringArrayRoundTrips(kind: StoreKind, value: [String]) throws {
        try withStore(kind) { store in
            store.setStringArray(value, forKey: "key")
            #expect(store.stringArray(forKey: "key") == value)
        }
    }

    @Test("A date reads back as written", arguments: StoreKind.allCases)
    func dateRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setDate(sampleDate, forKey: "key")
            #expect(store.date(forKey: "key") == sampleDate)
        }
    }

    @Test("Data reads back as written", arguments: StoreKind.allCases)
    func dataRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setData(sampleData, forKey: "key")
            #expect(store.data(forKey: "key") == sampleData)
        }
    }

    /// Empty data is stored rather than treated as a removal, the same way an empty
    /// string and an empty array are.
    @Test("Empty data is stored rather than treated as a removal",
          arguments: StoreKind.allCases)
    func emptyDataIsStored(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setData(Data(), forKey: "key")

            #expect(store.contains(key: "key"))
            #expect(store.data(forKey: "key") == Data())
        }
    }

    /// A URL round trips through the text it is stored as, in every part.
    ///
    /// `absoluteString` is the representation, so a store that dropped the query or
    /// the fragment, or that re-encoded the path, fails here. `sampleURL` carries all
    /// of those parts for that reason.
    @Test("A URL reads back as written", arguments: StoreKind.allCases)
    func urlRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            let url = try sampleURL()
            store.setURL(url, forKey: "key")
            #expect(store.url(forKey: "key") == url)
        }
    }

    /// A file URL is stored by the same rule as any other, which is the point of the
    /// rule.
    ///
    /// `UserDefaults.set(_:forKey:)` writes a file URL as a bare path and every other
    /// URL as an `NSKeyedArchiver` blob, so its two kinds of URL are two formats. Here
    /// they are one, and a file URL keeps its scheme.
    @Test("A file URL reads back as a file URL", arguments: StoreKind.allCases)
    func fileURLRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            let url = URL(fileURLWithPath: "/tmp/a b.txt")
            store.setURL(url, forKey: "key")

            #expect(store.url(forKey: "key") == url)
            #expect(store.url(forKey: "key")?.isFileURL == true)
        }
    }

    /// The URL endpoints and the string endpoints are two readings of one stored
    /// value, which is what makes a stored URL legible in a `plist`.
    @Test("A URL and a string are two readings of the same stored text",
          arguments: StoreKind.allCases)
    func urlAndStringReadTheSameValue(kind: StoreKind) throws {
        try withStore(kind) { store in
            let url = try sampleURL()
            store.setURL(url, forKey: "written-as-url")
            store.setString(url.absoluteString, forKey: "written-as-string")

            #expect(store.string(forKey: "written-as-url") == url.absoluteString)
            #expect(store.url(forKey: "written-as-string") == url)
        }
    }

    /// `setPropertyList` is the way in for a value none of the typed setters
    /// describes, and every case must arrive intact enough for the matching typed
    /// reader to find it.
    @Test("A property list value reaches its typed reader",
          arguments: StoreKind.allCases)
    func propertyListWritesReachTheTypedReaders(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setPropertyList("abc", forKey: "text")
            store.setPropertyList(42, forKey: "number")
            store.setPropertyList(3.5, forKey: "fraction")
            store.setPropertyList(true, forKey: "flag")
            store.setPropertyList(.date(sampleDate), forKey: "moment")
            store.setPropertyList(.data(sampleData), forKey: "blob")
            store.setPropertyList(["a", "b"], forKey: "list")

            #expect(store.string(forKey: "text") == "abc")
            #expect(store.int(forKey: "number") == 42)
            #expect(store.double(forKey: "fraction") == 3.5)
            #expect(store.bool(forKey: "flag") == true)
            #expect(store.date(forKey: "moment") == sampleDate)
            #expect(store.data(forKey: "blob") == sampleData)
            #expect(store.stringArray(forKey: "list") == ["a", "b"])
        }
    }

    /// A nested value survives, so the two container cases are not flattened or
    /// stringified on the way in.
    ///
    /// The dictionary reaches no typed reader, which is deliberate: there is no
    /// endpoint that returns one. What is checked is that the write is accepted, that
    /// the key is present afterwards, and that a value nested two levels down is still
    /// reachable through the array reader when it is put somewhere one can reach.
    @Test("A nested property list value is stored whole",
          arguments: StoreKind.allCases)
    func nestedPropertyListValuesAreStored(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setPropertyList(
                ["counts": [1, 2, 3], "names": ["a", "b"], "seen": true],
                forKey: "nested"
            )
            store.setPropertyList(.array([.string("a"), .string("b")]), forKey: "list")

            #expect(store.contains(key: "nested"))
            #expect(store.stringArray(forKey: "nested") == nil)
            #expect(store.stringArray(forKey: "list") == ["a", "b"])
        }
    }

    /// The contract on presence is presence, not type.
    ///
    /// Live `UserDefaults` normalises a value into its Foundation counterpart on the
    /// way in, so a stored `Int` is an `NSNumber` there and an `Int` in the in-memory
    /// store. No endpoint returns the stored value itself any more, so that difference
    /// is unobservable, and what both stores must agree on is whether the key is there
    /// at all.
    @Test("Any write makes the key present",
          arguments: StoreKind.allCases, SeededValue.allCases)
    func aWrittenKeyIsPresent(kind: StoreKind, seeded: SeededValue) throws {
        try withStore(kind) { store in
            try seeded.write(into: store, key: "key")
            #expect(store.contains(key: "key"))
        }
    }

    @Test("A later write replaces an earlier one, including across types",
          arguments: StoreKind.allCases)
    func lastWriteWins(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(42, forKey: "key")
            #expect(store.int(forKey: "key") == 42)

            store.setString("abc", forKey: "key")
            #expect(store.string(forKey: "key") == "abc")
            #expect(store.int(forKey: "key") == 0)
        }
    }

    @Test("Keys do not interfere with each other", arguments: StoreKind.allCases)
    func keysAreIndependent(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setInt(1, forKey: "first")
            store.setInt(2, forKey: "second")

            store.removeValue(forKey: "first")

            #expect(store.int(forKey: "first") == nil)
            #expect(store.int(forKey: "second") == 2)
        }
    }
}
