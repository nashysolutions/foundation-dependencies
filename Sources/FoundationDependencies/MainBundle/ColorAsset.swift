//
//  ColorAsset.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 22/05/2025.
//

import Foundation
import SwiftUI

/// A type-safe wrapper for referencing colour assets from a given bundle.
public struct ColorAsset: Hashable, Sendable, Identifiable {
    
    /// The identifier of the colour asset.
    ///
    /// This returns `self`, making the entire struct its own identifier.
    public var id: ColorAsset { self }
    
    /// The name of the colour asset.
    public let name: String
    
    /// The bundle in which the colour asset is located.
    public let bundle: Bundle
    
    /// A SwiftUI `Color` instance representing the asset.
    public var color: Color {
        Color(name, bundle: bundle)
    }
    
    /// Creates a new `ColorAsset` with the specified name and bundle.
    ///
    /// - Parameters:
    ///   - name: The name of the colour asset.
    ///   - bundle: The bundle where the colour asset is located.
    public init(name: String, bundle: Bundle) {
        self.name = name
        self.bundle = bundle
    }
    
    /// Hashes the essential components of the colour asset.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
