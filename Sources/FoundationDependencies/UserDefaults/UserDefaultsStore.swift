//
//  UserDefaultsStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// The operations both of this package's stores implement, so that
/// ``UserDefaultsClient`` can be built over either one without restating nineteen
/// closures twice.
///
/// Deliberately internal, and it is the only abstraction left in this module besides
/// the client. The published interface is ``UserDefaultsClient`` alone: a consumer
/// neither conforms to this nor sees it, so adding an endpoint here breaks nobody
/// outside the package, and a caller standing in for one endpoint replaces a closure
/// on the client rather than conforming to anything.
///
/// Every reader returns an optional, and `nil` from a scalar reader means the key
/// holds nothing. A key that holds something always has a reading through ``bool``,
/// ``int`` and ``double``, because live `UserDefaults` coerces rather than refusing,
/// so those three separate absence from every value including zero. The remaining
/// readers return `nil` for a key that holds nothing *and* for a key whose value has
/// no reading of that type, which is what live `UserDefaults` does and is why
/// ``contains(key:)`` exists.
///
/// Every requirement is synchronous and nonisolated, and the protocol refines
/// `Sendable`, which is what lets ``UserDefaultsClient`` capture a store in the
/// `@Sendable` closures it is made of. Thread safety is the conformer's to arrange and
/// each states at its own declaration how it does: ``UserDefaultsLiveStore`` leans on
/// `UserDefaults` being thread-safe, and ``UserDefaultsTestStore`` takes a lock around
/// its dictionary. A type that cannot make that argument for itself does not belong
/// here.
protocol UserDefaultsStore: Sendable {

    // MARK: - Reading Values

    func bool(forKey key: String) -> Bool?

    func int(forKey key: String) -> Int?

    func double(forKey key: String) -> Double?

    func string(forKey key: String) -> String?

    func stringArray(forKey key: String) -> [String]?

    func date(forKey key: String) -> Date?

    func data(forKey key: String) -> Data?

    func url(forKey key: String) -> URL?

    // MARK: - Presence

    func contains(key: String) -> Bool

    // MARK: - Writing Values

    func setBool(_ value: Bool, forKey key: String)

    func setInt(_ value: Int, forKey key: String)

    func setDouble(_ value: Double, forKey key: String)

    func setString(_ value: String?, forKey key: String)

    func setStringArray(_ value: [String]?, forKey key: String)

    func setDate(_ value: Date?, forKey key: String)

    func setData(_ value: Data?, forKey key: String)

    func setURL(_ value: URL?, forKey key: String)

    func setPropertyList(_ value: PropertyListValue?, forKey key: String)

    // MARK: - Deletion

    func removeValue(forKey key: String)
}
