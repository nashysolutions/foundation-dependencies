//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

public final class UserDefaultsTestStore: UserDefaultsStoreProtocol, @unchecked Sendable {
    
    private var storage: [String: Any] = [:]
    
    public init() {}

    // MARK: - Reading Values

    public var bool: @MainActor @Sendable (String) -> Bool {
        { [weak self] key in
            self?.storage[key] as? Bool ?? false
        }
    }
    
    public var int: @MainActor @Sendable (String) -> Int {
        { [weak self] key in
            self?.storage[key] as? Int ?? 0
        }
    }

    public var double: @MainActor @Sendable (String) -> Double {
        { [weak self] key in
            self?.storage[key] as? Double ?? 0
        }
    }
    
    public var string: @MainActor @Sendable (String) -> String? {
        { [weak self] key in
            self?.storage[key] as? String
        }
    }
    
    public var stringArray: @MainActor @Sendable (String) -> [String]? {
        { [weak self] key in
            self?.storage[key] as? [String]
        }
    }
    
    public var object: @MainActor @Sendable (String) -> Any? {
        { [weak self] key in
            self?.storage[key]
        }
    }
    
    public var date: @MainActor @Sendable (String) -> Date? {
        { [weak self] key in
            self?.storage[key] as? Date
        }
    }
    
    public var removeObject: @MainActor @Sendable (String) -> Void {
        { [weak self] key in
            self?.storage.removeValue(forKey: key)
        }
    }

    // MARK: - Writing Values

    public var setBool: @MainActor @Sendable (Bool, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }
    
    public var setInt: @MainActor @Sendable (Int, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }
    
    public var setDouble: @MainActor @Sendable (Double, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }

    public var setString: @MainActor @Sendable (String?, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }

    public var setStringArray: @MainActor @Sendable ([String]?, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }

    public var setObject: @MainActor @Sendable (Any?, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }

    public var setDate: @MainActor @Sendable (Date?, String) -> Void {
        { [weak self] value, key in
            self?.storage[key] = value
        }
    }
}
