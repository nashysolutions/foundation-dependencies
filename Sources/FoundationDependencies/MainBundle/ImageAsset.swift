//
//  ImageAsset.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 22/05/2025.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A type-safe wrapper for referencing image assets from a given bundle.
public struct ImageAsset: Hashable, Sendable, Identifiable {
    
    /// The identifier of the image asset.
    ///
    /// This returns `self`, making the entire struct its own identifier.
    public var id: ImageAsset { self }
    
    /// The name of the image asset.
    public let name: String
    
    /// The bundle in which the image asset is located.
    public let bundle: Bundle
    
    /// A SwiftUI `Image` instance representing the asset.
    public var image: Image {
        Image(name, bundle: bundle)
    }
    
    /// Creates a new `ImageAsset` with the specified name and bundle.
    ///
    /// - Parameters:
    ///   - name: The name of the image asset.
    ///   - bundle: The bundle where the image asset is located.
    public init(name: String, bundle: Bundle) {
        self.name = name
        self.bundle = bundle
    }
    
    /// Hashes the essential components of the image asset.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

#if canImport(UIKit)
public extension ImageAsset {
    
    /// Returns the PNG data for the image asset, if available.
    ///
    /// This is only available on platforms that support `UIKit`.
    var pngData: Data? {
        let image = UIImage(named: name, in: bundle, compatibleWith: nil)
        return image?.pngData()
    }
}
#endif
