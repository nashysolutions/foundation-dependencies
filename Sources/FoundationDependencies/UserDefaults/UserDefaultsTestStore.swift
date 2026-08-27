//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// An in-memory store for use in tests.
///
/// Values live in a dictionary owned by the instance, so a test neither reads nor
/// writes a real `UserDefaults` suite and nothing survives the process. Create one
/// per test to get a clean store, and wrap it in a ``UserDefaultsClient`` to install
/// it:
///
/// ```swift
/// let store = UserDefaultsTestStore()
/// store.setBool(true, forKey: "hasOnboarded")
///
/// withDependencies {
///     $0.userDefaultsClient = UserDefaultsClient(store)
/// } operation: {
///     // The code under test reads `true` for that key.
/// }
/// ```
///
/// ## Fidelity to live `UserDefaults`
///
/// A test double is only worth having if a test that passes against it would also
/// pass against production. `UserDefaults` coerces between types on read rather
/// than returning a default whenever the stored type differs from the requested
/// one, so the typed readers here reproduce those coercions instead of casting the
/// stored value directly. Reading a stored `"42"` through ``int`` returns `42`, and
/// reading a stored `"YES"` through ``bool`` returns `true`, exactly as they would
/// in production.
///
/// The rules are not the obvious ones and they are not symmetrical between readers.
/// `LiveUserDefaultsSemantics` is their authoritative home: it states each rule
/// against a measured example, and the readers below point at it rather than
/// restating it. Every rule was measured against a real `UserDefaults` suite rather
/// than taken from the prose documentation, which describes the coercions only in
/// general terms.
///
/// Writes are validated the same way. `UserDefaults` raises
/// `NSInvalidArgumentException` when asked to store a value that is not a property
/// list type, so ``setObject`` traps on the same input rather than accepting it
/// into the dictionary.
///
/// ## Known divergence
///
/// ``object`` returns the value as it was written, whereas live `UserDefaults`
/// returns the Foundation counterpart it normalised the value into on write. A
/// value stored through ``setInt`` therefore reads back from ``object`` as an `Int`
/// here and as an `NSNumber` in production, which matters only to a test that casts
/// the result to a different type than it stored: `object(key) as? Bool` finds a
/// `Bool` in production for a stored `1` and finds nothing here. The typed readers
/// are unaffected, and are the endpoints a test should prefer.
///
/// ## Thread safety
///
/// The `Sendable` conformance is `@unchecked` because `storage` is mutable state on
/// a class, which the compiler cannot prove is free of races on its own. What makes
/// it safe is that `storage` is `private`, that the only two things which touch it
/// are ``value(forKey:)`` and ``write(_:forKey:)`` at the foot of the type, and that
/// both hold `lock` for the whole of their access. Every endpoint goes through one
/// of those two, so no endpoint can read the dictionary while another is writing it.
///
/// The endpoints are synchronous and nonisolated, matching the rest of this package,
/// and ``UserDefaultsClient`` captures a whole store in the `@Sendable` closures it is
/// made of, so a store genuinely can be called from two domains at once and the lock is
/// not ceremony. It replaced an earlier arrangement that made every endpoint
/// `@MainActor` and leaned on that for serialisation, which cost every caller off the
/// main actor a hop and made the double harder to use than the thing it doubles.
///
/// The rule the conformance rests on is that nothing else reaches `storage` directly.
/// Add an endpoint that does and the guarantee is gone, with no compiler diagnostic
/// pointing back at this conformance; call one of the two accessors instead and there
/// is nothing to remember.
public final class UserDefaultsTestStore: UserDefaultsStore, @unchecked Sendable {

    /// The backing store.
    ///
    /// Holds each value exactly as it was written, without the normalisation into
    /// Foundation types that live `UserDefaults` performs on the way in. A value
    /// written through ``setInt`` is still a Swift `Int` when it comes back out of
    /// ``object``, which is the divergence described on the type.
    ///
    /// Only ever read through ``value(forKey:)`` and written through
    /// ``write(_:forKey:)``, both of which hold ``lock``. See the thread safety note.
    private var storage: [String: Any] = [:]

    /// Guards ``storage``.
    ///
    /// `NSLock` rather than an actor because every endpoint here is synchronous and
    /// returns its value to the caller. An actor would make each one `async`, which
    /// ``UserDefaultsClient`` does not allow, and which live `UserDefaults` does not
    /// require of a caller either.
    private let lock = NSLock()

    /// Creates an empty store.
    public init() {}

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.boolean(from:)` for the rules.
    public func bool(forKey key: String) -> Bool {
        LiveUserDefaultsSemantics.boolean(from: value(forKey: key))
    }

    /// Retrieves an integer value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.integer(from:)` for the rules.
    public func int(forKey key: String) -> Int {
        LiveUserDefaultsSemantics.integer(from: value(forKey: key))
    }

    /// Retrieves a double value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.double(from:)` for the rules.
    public func double(forKey key: String) -> Double {
        LiveUserDefaultsSemantics.double(from: value(forKey: key))
    }

    /// Retrieves a string value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.string(from:)` for the rules.
    public func string(forKey key: String) -> String? {
        LiveUserDefaultsSemantics.string(from: value(forKey: key))
    }

    /// Retrieves an array of strings for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.stringArray(from:)` for the rules.
    public func stringArray(forKey key: String) -> [String]? {
        LiveUserDefaultsSemantics.stringArray(from: value(forKey: key))
    }

    /// Retrieves the stored value for the specified key, or `nil` if there is none.
    ///
    /// Unlike the typed readers this performs no coercion. See the known divergence
    /// note on the type for how the returned value differs from production.
    public func object(forKey key: String) -> Any? {
        value(forKey: key)
    }

    /// Retrieves a `Date` value for the specified key.
    ///
    /// Returns `nil` when the stored value is anything other than a date. A number
    /// is not interpreted as a time interval, matching production.
    public func date(forKey key: String) -> Date? {
        value(forKey: key) as? Date
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public func setBool(_ value: Bool, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores an integer value for the specified key.
    public func setInt(_ value: Int, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a double value for the specified key.
    public func setDouble(_ value: Double, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a string value for the specified key, or removes the key when `value`
    /// is `nil`.
    public func setString(_ value: String?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores an array of strings for the specified key, or removes the key when
    /// `value` is `nil`.
    public func setStringArray(_ value: [String]?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a raw value for the specified key, or removes the key when `value` is
    /// `nil`.
    ///
    /// - Precondition: `value` is a property list value. `UserDefaults` raises
    ///   `NSInvalidArgumentException` for anything else, so accepting it here would
    ///   let a test pass against behaviour production does not have. Note that this
    ///   rejects `URL`, which production also rejects through this endpoint even
    ///   though its dedicated `set(_:forKey:)` overload for URLs accepts one.
    public func setObject(_ value: Any?, forKey key: String) {
        if let value {
            precondition(
                PropertyListSerialization.propertyList(value, isValidFor: .binary),
                """
                Cannot store a value of type \(type(of: value)) for key '\(key)'. \
                UserDefaults accepts only property list values: String, a number, \
                Bool, Date, Data, or an Array or Dictionary of those with String \
                keys. Live UserDefaults raises NSInvalidArgumentException here.
                """
            )
        }
        write(value, forKey: key)
    }

    /// Stores a `Date` value for the specified key, or removes the key when `value`
    /// is `nil`.
    public func setDate(_ value: Date?, forKey key: String) {
        write(value, forKey: key)
    }

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    public func removeObject(forKey key: String) {
        write(nil, forKey: key)
    }

    // MARK: - Storage

    /// Returns the value stored under `key`, or `nil` when there is none.
    ///
    /// One of the two places `storage` is touched. The lock is given back before the
    /// readers do anything with the result, because neither the coercions nor the
    /// `as? Date` cast needs the dictionary.
    private func value(forKey key: String) -> Any? {
        lock.withLock { storage[key] }
    }

    /// Stores `value` under `key`, removing the key when `value` is `nil`.
    ///
    /// Live `UserDefaults` treats a `nil` write as a removal rather than storing an
    /// empty placeholder, so afterwards both stores agree that the key is absent. The
    /// setters that cannot receive `nil` call this too rather than assigning to
    /// `storage` themselves, which is what keeps the count of places that touch the
    /// dictionary at two.
    private func write(_ value: Any?, forKey key: String) {
        lock.withLock {
            // Assigning `nil` through a dictionary subscript removes the key rather
            // than storing an empty box, which is the behaviour described above.
            storage[key] = value
        }
    }
}
