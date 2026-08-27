//
//  UserDefaultsCodableTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// A value of the shape a consumer actually stores: a few settings in one struct,
/// rather than a single scalar dressed up as an object.
private struct Preferences: Codable, Equatable, Sendable {

    var theme: String
    var launches: Int
    var lastSeen: Date
    var enabled: Bool
}

/// What the `Codable` methods must do, against both stores.
///
/// They are the endpoints' one composite: `decode` reads through `data` and `encode`
/// writes through `setData`, so a divergence between the stores in either of those
/// shows up here as well. That is the reason these cases run against both kinds rather
/// than against the in-memory store alone, where a JSON round trip would be a test of
/// `JSONEncoder`.
@Suite("Codable values")
@MainActor
struct UserDefaultsCodableTests {

    private static let sample = Preferences(
        theme: "dark",
        launches: 12,
        lastSeen: sampleDate,
        enabled: true
    )

    @Test("A Codable value reads back as written", arguments: StoreKind.allCases)
    func codableRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            try store.encode(Self.sample, forKey: "prefs")

            let decoded = try store.decode(Preferences.self, forKey: "prefs")
            #expect(decoded == Self.sample)
        }
    }

    /// A top level fragment is not an object or an array, and `JSONEncoder` used to
    /// refuse one. It does not on any toolchain this package supports, and a consumer
    /// storing a bare `Int` through this path should not have to know that, so it is
    /// asserted rather than assumed.
    @Test("A top level fragment round trips", arguments: StoreKind.allCases)
    func fragmentRoundTrips(kind: StoreKind) throws {
        try withStore(kind) { store in
            try store.encode(42, forKey: "number")
            try store.encode("abc", forKey: "text")
            try store.encode([1, 2, 3], forKey: "list")

            let number = try store.decode(Int.self, forKey: "number")
            let text = try store.decode(String.self, forKey: "text")
            let list = try store.decode([Int].self, forKey: "list")

            #expect(number == 42)
            #expect(text == "abc")
            #expect(list == [1, 2, 3])
        }
    }

    /// Absence is `nil` rather than a throw. Not having stored a value yet is
    /// ordinary, and every other reader answers it the same way.
    @Test("A key that holds nothing decodes as nil", arguments: StoreKind.allCases)
    func absentKeyDecodesAsNil(kind: StoreKind) throws {
        try withStore(kind) { store in
            let decoded = try store.decode(Preferences.self, forKey: "never-written")
            #expect(decoded == nil)
        }
    }

    /// A key holding something that is not data is `nil` too, for the same reason
    /// `data` is `nil` for it: there are no bytes to decode, and inventing some from
    /// the stored text would be a coercion live `UserDefaults` does not perform.
    @Test("A key that holds something other than data decodes as nil",
          arguments: StoreKind.allCases)
    func nonDataDecodesAsNil(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setString("abc", forKey: "text")
            store.setInt(42, forKey: "number")

            let fromText = try store.decode(Preferences.self, forKey: "text")
            let fromNumber = try store.decode(Preferences.self, forKey: "number")

            #expect(fromText == nil)
            #expect(fromNumber == nil)
        }
    }

    /// Data that is present and does not decode throws, and that is the half of the
    /// contract worth being careful about. It is the shape of a value written by an
    /// earlier version of the app, and answering `nil` would turn a migration defect
    /// into a silent reset the caller never hears about.
    @Test("Data that does not decode throws rather than reading as nil",
          arguments: StoreKind.allCases)
    func undecodableDataThrows(kind: StoreKind) throws {
        try withStore(kind) { store in
            store.setData(Data("not json at all".utf8), forKey: "broken")
            try store.encode(["unrelated": "shape"], forKey: "mismatched")

            #expect(throws: (any Error).self) {
                try store.decode(Preferences.self, forKey: "broken")
            }
            #expect(throws: (any Error).self) {
                try store.decode(Preferences.self, forKey: "mismatched")
            }
        }
    }

    /// Encoding `nil` removes the key, which is what every other setter that accepts
    /// one does.
    @Test("Encoding nil removes the key", arguments: StoreKind.allCases)
    func encodingNilRemovesTheKey(kind: StoreKind) throws {
        try withStore(kind) { store in
            try store.encode(Self.sample, forKey: "prefs")
            #expect(store.contains(key: "prefs"))

            try store.encode(nil as Preferences?, forKey: "prefs")

            expectAbsent(store, key: "prefs")
        }
    }

    /// The stored value is data, not a private box, so `data` reads the bytes and the
    /// key behaves like any other key holding a blob.
    @Test("An encoded value is stored as data", arguments: StoreKind.allCases)
    func anEncodedValueIsStoredAsData(kind: StoreKind) throws {
        try withStore(kind) { store in
            try store.encode(Self.sample, forKey: "prefs")

            let raw = try #require(store.data(forKey: "prefs"))
            let decoded = try JSONDecoder().decode(Preferences.self, from: raw)

            #expect(decoded == Self.sample)
            #expect(store.string(forKey: "prefs") == nil)
        }
    }
}
