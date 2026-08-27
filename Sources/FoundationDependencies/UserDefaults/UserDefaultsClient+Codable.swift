//
//  UserDefaultsClient+Codable.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation

/// Reading and writing a `Codable` value.
///
/// These are methods rather than endpoints because an endpoint is a stored closure and
/// a stored closure cannot be generic. That is not a workaround. Both sides go through
/// ``UserDefaultsClient/data`` and ``UserDefaultsClient/setData``, so a test that
/// replaces those two endpoints has replaced the `Codable` path as well, and a test
/// that seeds a store with JSON has seeded it. There is no third thing to stub.
public extension UserDefaultsClient {

    /// Decodes a value of the given type from JSON stored under `key`.
    ///
    /// ```swift
    /// let settings = try userDefaults.decode(Settings.self, forKey: "settings")
    /// ```
    ///
    /// The two failure modes are deliberately different. A key that holds nothing, or
    /// holds something that is not data, returns `nil`: not having stored a value yet
    /// is ordinary, and every other reader answers it the same way. Data that is
    /// present but does not decode throws, because that is a value written by an
    /// earlier version of the app or by something else entirely, and swallowing it
    /// would turn a migration defect into a silent reset.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - key: The key to read.
    ///
    /// - Returns: The decoded value, or `nil` when the key holds no data.
    ///
    /// - Throws: Whatever `JSONDecoder` throws for data that does not decode as
    ///           `type`.
    func decode<Value: Decodable>(_ type: Value.Type, forKey key: String) throws -> Value? {
        guard let data = data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(type, from: data)
    }

    /// Encodes a value as JSON and stores it under `key`, or removes the key when
    /// `value` is `nil`.
    ///
    /// ```swift
    /// try userDefaults.encode(settings, forKey: "settings")
    /// ```
    ///
    /// Removing on `nil` is what every other setter that accepts one does, so a
    /// caller clearing a stored value writes the same thing here as anywhere else.
    ///
    /// - Parameters:
    ///   - value: The value to store, or `nil` to remove the key.
    ///   - key: The key to write.
    ///
    /// - Throws: Whatever `JSONEncoder` throws for a value it cannot encode, such as
    ///           a non-conforming floating point value.
    func encode<Value: Encodable>(_ value: Value?, forKey key: String) throws {
        guard let value else {
            setData(nil, forKey: key)
            return
        }
        setData(try JSONEncoder().encode(value), forKey: key)
    }
}
