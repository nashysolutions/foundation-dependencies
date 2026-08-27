//
//  UserDefaultsStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// The operations both of this package's stores implement, so that
/// ``UserDefaultsClient`` can be built over either one without restating fifteen
/// closures twice.
///
/// Deliberately internal, and it is the only abstraction left in this module besides
/// the client. The published interface is ``UserDefaultsClient`` alone: a consumer
/// neither conforms to this nor sees it, so adding an endpoint here breaks nobody
/// outside the package, and a caller standing in for one endpoint replaces a closure
/// on the client rather than conforming to anything.
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

    func bool(forKey key: String) -> Bool

    func int(forKey key: String) -> Int

    func double(forKey key: String) -> Double

    func string(forKey key: String) -> String?

    func stringArray(forKey key: String) -> [String]?

    func object(forKey key: String) -> Any?

    func date(forKey key: String) -> Date?

    // MARK: - Writing Values

    func setBool(_ value: Bool, forKey key: String)

    func setInt(_ value: Int, forKey key: String)

    func setDouble(_ value: Double, forKey key: String)

    func setString(_ value: String?, forKey key: String)

    func setStringArray(_ value: [String]?, forKey key: String)

    func setObject(_ value: Any?, forKey key: String)

    func setDate(_ value: Date?, forKey key: String)

    // MARK: - Deletion

    func removeObject(forKey key: String)
}
