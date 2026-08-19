//
//  UserDefaultsClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Dependencies

/// A concrete implementation of `UserDefaultsStoreProtocol` backed by user-supplied closures.
///
/// `UserDefaultsClient` allows you to inject a custom implementation of user defaults
/// functionality—useful for testing, mocking, or adapting to different storage systems.
///
/// Every operation is a nonisolated `@Sendable` closure, so a client may be resolved
/// and called from any concurrency domain. Nothing here serialises those calls, so
/// whatever the closures you supply capture has to be safe to touch from more than
/// one at a time. Capturing nothing mutable is the easy way; holding the mutable
/// state behind a lock, as ``UserDefaultsTestStore`` does, is the other.
///
/// This type is `Sendable` and can be used as a dependency in Swift Concurrency environments.
public struct UserDefaultsClient: UserDefaultsStoreProtocol {

    // MARK: - Stored Closures

    /// Retrieves a Boolean value for a given key.
    public var bool: @Sendable (String) -> Bool

    /// Retrieves an integer value for a given key.
    public var int: @Sendable (String) -> Int

    /// Retrieves a double value for a given key.
    public var double: @Sendable (String) -> Double

    /// Retrieves a string value for a given key.
    public var string: @Sendable (String) -> String?

    /// Retrieves an array of strings for a given key.
    public var stringArray: @Sendable (String) -> [String]?

    /// Retrieves a raw object for a given key.
    public var object: @Sendable (String) -> Any?

    /// Retrieves a `Date` value for a given key.
    public var date: @Sendable (String) -> Date?

    /// Removes the value associated with the given key.
    public var removeObject: @Sendable (String) -> Void

    /// Stores a Boolean value for a given key.
    public var setBool: @Sendable (Bool, String) -> Void

    /// Stores an integer value for a given key.
    public var setInt: @Sendable (Int, String) -> Void

    /// Stores a double value for a given key.
    public var setDouble: @Sendable (Double, String) -> Void

    /// Stores a string value for a given key.
    public var setString: @Sendable (String?, String) -> Void

    /// Stores an array of strings for a given key.
    public var setStringArray: @Sendable ([String]?, String) -> Void

    /// Stores a raw object for a given key.
    public var setObject: @Sendable (Any?, String) -> Void

    /// Stores a `Date` value for a given key.
    public var setDate: @Sendable (Date?, String) -> Void

    // MARK: - Initialiser

    /// Creates a new `UserDefaultsClient` using the provided closures for each operation.
    ///
    /// - Parameters:
    ///   - bool: Closure to retrieve a `Bool` for a given key.
    ///   - int: Closure to retrieve an `Int` for a given key.
    ///   - double: Closure to retrieve a `Double` for a given key.
    ///   - string: Closure to retrieve a `String?` for a given key.
    ///   - stringArray: Closure to retrieve a `[String]?` for a given key.
    ///   - object: Closure to retrieve an `Any?` for a given key.
    ///   - date: Closure to retrieve a `Date?` for a given key.
    ///   - removeObject: Closure to remove a value for a given key.
    ///   - setBool: Closure to store a `Bool` for a given key.
    ///   - setInt: Closure to store an `Int` for a given key.
    ///   - setDouble: Closure to store a `Double` for a given key.
    ///   - setString: Closure to store a `String?` for a given key.
    ///   - setStringArray: Closure to store a `[String]?` for a given key.
    ///   - setObject: Closure to store an `Any?` for a given key.
    ///   - setDate: Closure to store a `Date?` for a given key.
    public init(
        bool: @Sendable @escaping (String) -> Bool,
        int: @Sendable @escaping (String) -> Int,
        double: @Sendable @escaping (String) -> Double,
        string: @Sendable @escaping (String) -> String?,
        stringArray: @Sendable @escaping (String) -> [String]?,
        object: @Sendable @escaping (String) -> Any?,
        date: @Sendable @escaping (String) -> Date?,
        removeObject: @Sendable @escaping (String) -> Void,
        setBool: @Sendable @escaping (Bool, String) -> Void,
        setInt: @Sendable @escaping (Int, String) -> Void,
        setDouble: @Sendable @escaping (Double, String) -> Void,
        setString: @Sendable @escaping (String?, String) -> Void,
        setStringArray: @Sendable @escaping ([String]?, String) -> Void,
        setObject: @Sendable @escaping (Any?, String) -> Void,
        setDate: @Sendable @escaping (Date?, String) -> Void
    ) {
        self.bool = bool
        self.int = int
        self.double = double
        self.string = string
        self.stringArray = stringArray
        self.object = object
        self.date = date
        self.removeObject = removeObject
        self.setBool = setBool
        self.setInt = setInt
        self.setDouble = setDouble
        self.setString = setString
        self.setStringArray = setStringArray
        self.setObject = setObject
        self.setDate = setDate
    }
}

/// A test dependency key for injecting a stubbed user defaults client in unit tests.
public enum UserDefaultsKey: TestDependencyKey {

    /// A test implementation of `UserDefaultsStoreProtocol` using in-memory storage.
    ///
    /// Computed rather than stored, and it has to stay that way. `UserDefaultsTestStore`
    /// is a class holding a dictionary, so a stored property would be one store for the
    /// whole process: every test that installs no store of its own would resolve that
    /// same instance, and a value written by one test would still be sitting there for
    /// the next one to read. Reading this property builds a store instead.
    ///
    /// That is not the same as a new store on every resolution, which would be just as
    /// wrong in the other direction. `swift-dependencies` caches what it resolves, keyed
    /// on the running test, so a test that resolves the dependency twice is handed the
    /// same store both times and a write made through one resolution is visible through
    /// the other. Freshness is per test, sameness is within a test, and a caller that
    /// stores a value and reads it back needs the second of those as much as isolation
    /// needs the first.
    ///
    /// `UserDefaultsDefaultStoreIsolationTests` holds both. It fails in the first
    /// direction if this goes back to being a stored property, and in the second if a
    /// later change hands out a store per resolution rather than per test.
    public static var testValue: any UserDefaultsStoreProtocol {
        UserDefaultsTestStore()
    }
}

/// Extension for registering and accessing the `UserDefaultsStoreProtocol` client
/// in the dependency injection system.
public extension DependencyValues {

    /// The user defaults client available in the current dependency context.
    ///
    /// Use this to access or override the user defaults client for testing.
    var userDefaultsClient: any UserDefaultsStoreProtocol {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
}
