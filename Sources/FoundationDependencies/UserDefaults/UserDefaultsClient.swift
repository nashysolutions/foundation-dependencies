//
//  UserDefaultsClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Dependencies

/// A value-type interface for interacting with user defaults in a testable and dependency-injected manner.
///
/// `UserDefaultsClient` wraps standard operations on `UserDefaults` using simple closures.
public struct UserDefaultsClient: Sendable {

    // MARK: - Stored Closures

    /// Retrieves a Boolean value for a given key.
    public var bool: @Sendable (String) -> Bool

    /// Stores a Boolean value for a given key.
    public var setBool: @Sendable (Bool, String) -> Void

    /// Retrieves a string value for a given key.
    public var string: @Sendable (String) -> String?

    /// Stores a string value for a given key.
    public var setString: @Sendable (String?, String) -> Void

    /// Retrieves an array of strings for a given key.
    public var stringArray: @Sendable (String) -> [String]?

    /// Stores an array of strings for a given key.
    public var setStringArray: @Sendable ([String]?, String) -> Void

    /// Retrieves a raw object for a given key.
    public var object: @Sendable (String) -> Any?

    /// Stores a raw object for a given key.
    public var setObject: @Sendable (Any?, String) -> Void

    /// Retrieves a `Date` value for a given key.
    public var date: @Sendable (String) -> Date?

    /// Stores a `Date` value for a given key.
    public var setDate: @Sendable (Date?, String) -> Void

    /// Removes the value associated with the given key.
    public var removeObject: @Sendable (String) -> Void

    // MARK: - Initialiser

    /// Creates a new `UserDefaultsClient` using the provided closures for each operation.
    ///
    /// - Parameters:
    ///   - bool: A closure to retrieve a `Bool` value for a key.
    ///   - setBool: A closure to store a `Bool` value for a key.
    ///   - string: A closure to retrieve a `String?` value for a key.
    ///   - setString: A closure to store a `String?` value for a key.
    ///   - stringArray: A closure to retrieve a `[String]?` value for a key.
    ///   - setStringArray: A closure to store a `[String]?` value for a key.
    ///   - object: A closure to retrieve an `Any?` value for a key.
    ///   - setObject: A closure to store an `Any?` value for a key.
    ///   - date: A closure to retrieve a `Date?` value for a key.
    ///   - setDate: A closure to store a `Date?` value for a key.
    ///   - removeObject: A closure to remove a value for a key.
    public init(
        bool: @Sendable @escaping (String) -> Bool,
        setBool: @Sendable @escaping (Bool, String) -> Void,
        string: @Sendable @escaping (String) -> String?,
        setString: @Sendable @escaping (String?, String) -> Void,
        stringArray: @Sendable @escaping (String) -> [String]?,
        setStringArray: @Sendable @escaping ([String]?, String) -> Void,
        object: @Sendable @escaping (String) -> Any?,
        setObject: @Sendable @escaping (Any?, String) -> Void,
        date: @Sendable @escaping (String) -> Date?,
        setDate: @Sendable @escaping (Date?, String) -> Void,
        removeObject: @Sendable @escaping (String) -> Void
    ) {
        self.bool = bool
        self.setBool = setBool
        self.string = string
        self.setString = setString
        self.stringArray = stringArray
        self.setStringArray = setStringArray
        self.object = object
        self.setObject = setObject
        self.date = date
        self.setDate = setDate
        self.removeObject = removeObject
    }
}

public extension UserDefaultsClient {

    /// Creates a `UserDefaultsClient` from an instance conforming to `UserDefaultsStoreProtocol`.
    ///
    /// This allows for dependency injection using a custom or mock store implementation,
    /// which is useful in testing environments or alternate backends.
    ///
    /// - Parameter store: A type conforming to `UserDefaultsStoreProtocol`.
    /// - Returns: A `UserDefaultsClient` that delegates calls to the provided store.
    static func from(store: UserDefaultsStoreProtocol) -> UserDefaultsClient {
        .init(
            bool: { store.bool(forKey: $0) },
            setBool: { store.set($0, forKey: $1) },
            string: { store.string(forKey: $0) },
            setString: { store.set($0, forKey: $1) },
            stringArray: { store.stringArray(forKey: $0) },
            setStringArray: { store.set($0, forKey: $1) },
            object: { store.object(forKey: $0) },
            setObject: { store.set($0, forKey: $1) },
            date: { store.date(forKey: $0) },
            setDate: { store.set($0, forKey: $1) },
            removeObject: { store.removeObject(forKey: $0) }
        )
    }
}

public enum UserDefaultsKey: TestDependencyKey {
    public static let testValue: UserDefaultsClient = .from(store: UserDefaultsTestStore())
}

public extension DependencyValues {
    
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
}

