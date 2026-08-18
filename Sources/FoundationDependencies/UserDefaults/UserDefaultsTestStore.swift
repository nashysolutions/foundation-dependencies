//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// An in-memory implementation of ``UserDefaultsStoreProtocol`` for use in tests.
///
/// Values live in a dictionary owned by the instance, so a test neither reads nor
/// writes a real `UserDefaults` suite and nothing survives the process. Create one
/// per test to get a clean store.
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
/// it safe is that `storage` is `private` and every closure that touches it is
/// declared `@MainActor`, so all access is serialised on the main actor. Adding an
/// endpoint that reads or writes `storage` from anywhere other than a `@MainActor`
/// closure would break that guarantee, and no compiler diagnostic would point back
/// at this conformance when it did.
public final class UserDefaultsTestStore: UserDefaultsStoreProtocol, @unchecked Sendable {

    /// The backing store.
    ///
    /// Holds each value exactly as it was written, without the normalisation into
    /// Foundation types that live `UserDefaults` performs on the way in. A value
    /// written through ``setInt`` is still a Swift `Int` when it comes back out of
    /// ``object``, which is the divergence described on the type.
    ///
    /// Only ever read or written from the `@MainActor` closures below and from the
    /// `@MainActor` helper at the foot of the type. See the thread safety note.
    private var storage: [String: Any] = [:]

    /// Creates an empty store.
    public init() {}

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.boolean(from:)` for the rules.
    public var bool: @MainActor @Sendable (String) -> Bool {
        { key in
            LiveUserDefaultsSemantics.boolean(from: self.storage[key])
        }
    }

    /// Retrieves an integer value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.integer(from:)` for the rules.
    public var int: @MainActor @Sendable (String) -> Int {
        { key in
            LiveUserDefaultsSemantics.integer(from: self.storage[key])
        }
    }

    /// Retrieves a double value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.double(from:)` for the rules.
    public var double: @MainActor @Sendable (String) -> Double {
        { key in
            LiveUserDefaultsSemantics.double(from: self.storage[key])
        }
    }

    /// Retrieves a string value for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.string(from:)` for the rules.
    public var string: @MainActor @Sendable (String) -> String? {
        { key in
            LiveUserDefaultsSemantics.string(from: self.storage[key])
        }
    }

    /// Retrieves an array of strings for the specified key.
    ///
    /// Coerces the stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.stringArray(from:)` for the rules.
    public var stringArray: @MainActor @Sendable (String) -> [String]? {
        { key in
            LiveUserDefaultsSemantics.stringArray(from: self.storage[key])
        }
    }

    /// Retrieves the stored value for the specified key, or `nil` if there is none.
    ///
    /// Unlike the typed readers this performs no coercion. See the known divergence
    /// note on the type for how the returned value differs from production.
    public var object: @MainActor @Sendable (String) -> Any? {
        { key in
            self.storage[key]
        }
    }

    /// Retrieves a `Date` value for the specified key.
    ///
    /// Returns `nil` when the stored value is anything other than a date. A number
    /// is not interpreted as a time interval, matching production.
    public var date: @MainActor @Sendable (String) -> Date? {
        { key in
            self.storage[key] as? Date
        }
    }

    /// Removes the value associated with the specified key.
    public var removeObject: @MainActor @Sendable (String) -> Void {
        { key in
            self.storage.removeValue(forKey: key)
        }
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @MainActor @Sendable (Bool, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores an integer value for the specified key.
    public var setInt: @MainActor @Sendable (Int, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores a double value for the specified key.
    public var setDouble: @MainActor @Sendable (Double, String) -> Void {
        { value, key in
            self.storage[key] = value
        }
    }

    /// Stores a string value for the specified key, or removes the key when `value`
    /// is `nil`.
    public var setString: @MainActor @Sendable (String?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    /// Stores an array of strings for the specified key, or removes the key when
    /// `value` is `nil`.
    public var setStringArray: @MainActor @Sendable ([String]?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    /// Stores a raw value for the specified key, or removes the key when `value` is
    /// `nil`.
    ///
    /// - Precondition: `value` is a property list value. `UserDefaults` raises
    ///   `NSInvalidArgumentException` for anything else, so accepting it here would
    ///   let a test pass against behaviour production does not have. Note that this
    ///   rejects `URL`, which production also rejects through this endpoint even
    ///   though its dedicated `set(_:forKey:)` overload for URLs accepts one.
    public var setObject: @MainActor @Sendable (Any?, String) -> Void {
        { value, key in
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
            self.write(value, forKey: key)
        }
    }

    /// Stores a `Date` value for the specified key, or removes the key when `value`
    /// is `nil`.
    public var setDate: @MainActor @Sendable (Date?, String) -> Void {
        { value, key in
            self.write(value, forKey: key)
        }
    }

    // MARK: - Storage

    /// Stores `value` under `key`, removing the key when `value` is `nil`.
    ///
    /// Live `UserDefaults` treats a `nil` write as a removal rather than storing an
    /// empty placeholder, so afterwards both stores agree that the key is absent.
    /// The setters that cannot receive `nil` assign to `storage` directly instead of
    /// calling this.
    ///
    /// Isolated to the main actor because it touches `storage`, which the type's
    /// `Sendable` conformance assumes is only ever reached from there. The
    /// annotation makes that a compiler check for this one function rather than
    /// something a future caller has to remember.
    @MainActor
    private func write(_ value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}
