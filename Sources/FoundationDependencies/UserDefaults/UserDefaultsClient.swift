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
/// All operations are isolated to the main actor and explicitly marked `@Sendable`
/// for safe usage in concurrent contexts.
///
/// This type is `Sendable` and can be used as a dependency in Swift Concurrency environments.
public struct UserDefaultsClient: UserDefaultsStoreProtocol {
    
    // MARK: - Stored Closures

    /// Retrieves a Boolean value for a given key.
    public var bool: @MainActor @Sendable (String) -> Bool

    /// Retrieves an integer value for a given key.
    public var int: @MainActor @Sendable (String) -> Int

    /// Retrieves a double value for a given key.
    public var double: @MainActor @Sendable (String) -> Double

    /// Retrieves a string value for a given key.
    public var string: @MainActor @Sendable (String) -> String?

    /// Retrieves an array of strings for a given key.
    public var stringArray: @MainActor @Sendable (String) -> [String]?

    /// Retrieves a raw object for a given key.
    public var object: @MainActor @Sendable (String) -> Any?

    /// Retrieves a `Date` value for a given key.
    public var date: @MainActor @Sendable (String) -> Date?

    /// Removes the value associated with the given key.
    public var removeObject: @MainActor @Sendable (String) -> Void

    /// Stores a Boolean value for a given key.
    public var setBool: @MainActor @Sendable (Bool, String) -> Void
    
    /// Stores an integer value for a given key.
    public var setInt: @MainActor @Sendable (Int, String) -> Void
    
    /// Stores a double value for a given key.
    public var setDouble: @MainActor @Sendable (Double, String) -> Void
    
    /// Stores a string value for a given key.
    public var setString: @MainActor @Sendable (String?, String) -> Void

    /// Stores an array of strings for a given key.
    public var setStringArray: @MainActor @Sendable ([String]?, String) -> Void

    /// Stores a raw object for a given key.
    public var setObject: @MainActor @Sendable (Any?, String) -> Void

    /// Stores a `Date` value for a given key.
    public var setDate: @MainActor @Sendable (Date?, String) -> Void

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
        bool: @MainActor @Sendable @escaping (String) -> Bool,
        int: @MainActor @Sendable @escaping (String) -> Int,
        double: @MainActor @Sendable @escaping (String) -> Double,
        string: @MainActor @Sendable @escaping (String) -> String?,
        stringArray: @MainActor @Sendable @escaping (String) -> [String]?,
        object: @MainActor @Sendable @escaping (String) -> Any?,
        date: @MainActor @Sendable @escaping (String) -> Date?,
        removeObject: @MainActor @Sendable @escaping (String) -> Void,
        setBool: @MainActor @Sendable @escaping (Bool, String) -> Void,
        setInt: @MainActor @Sendable @escaping (Int, String) -> Void,
        setDouble: @MainActor @Sendable @escaping (Double, String) -> Void,
        setString: @MainActor @Sendable @escaping (String?, String) -> Void,
        setStringArray: @MainActor @Sendable @escaping ([String]?, String) -> Void,
        setObject: @MainActor @Sendable @escaping (Any?, String) -> Void,
        setDate: @MainActor @Sendable @escaping (Date?, String) -> Void
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
    public static let testValue: any UserDefaultsStoreProtocol = UserDefaultsTestStore()
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
