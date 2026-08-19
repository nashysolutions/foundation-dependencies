//
//  DocumentationExampleStubs.swift
//  foundation-dependencies
//
//  Types the documentation examples assume the reader already owns.
//
//  `check-documentation-examples.swift` compiles every Swift fence in the
//  README and the DocC articles. A fence is allowed to refer to a type that
//  belongs to the reader's app rather than to this package — `ContentView` is
//  the obvious one — and there is nowhere else for such a type to come from.
//  This file supplies them, and nothing else.
//
//  Two rules keep this file from quietly weakening the gate it supports.
//
//  First, only add a declaration here when the name genuinely belongs to the
//  reader. A name this package is supposed to export belongs in `Sources`; if
//  a fence cannot resolve one, that is the fence or the package being wrong,
//  and stubbing it here would hide exactly the defect the gate exists to find.
//
//  Second, Swift resolves `import` per file, not per module. This file imports
//  SwiftUI so that `ContentView` can be a `View`, and that import is invisible
//  to every fence compiled alongside it. A fence that uses `App`, `Scene` or
//  `WindowGroup` without importing SwiftUI itself still fails, which is the
//  point: that omission is the defect recorded in issues #27 and #30.
//

import Foundation
import SwiftUI

/// The reader's root view, named by the `WindowGroup` in the app-entry examples.
struct ContentView: View {

    var body: some View {
        EmptyView()
    }
}

/// A stand-in for whatever the reader constructs inside a `withDependencies`
/// operation. A class rather than a struct because the scoping article passes
/// one of these to `withDependencies(from:)`, which requires a reference type.
final class MyService {}

/// The two collaborators in the dependency-scoping article. Both are reference
/// types for the same reason `MyService` is.
final class ItemA {}

/// The second collaborator in the dependency-scoping article.
final class ItemB {}

/// The instance the scoping article's second fence inherits dependencies from.
/// The fence that creates it is illustrative and carries an elision, so the
/// value has to come from somewhere; see the exemption recorded for it.
let itemA = ItemA()

extension Bundle {

    /// Stands in for the resource-bundle accessor SwiftPM synthesises inside a
    /// target that declares resources.
    ///
    /// The main-bundle article tells the reader to write `Bundle.module` in
    /// their own target, where SwiftPM generates it. There is no generated
    /// accessor in a bare type-check, so without this the article's advice
    /// could not be checked at all. `.main` is never read here — nothing in
    /// this gate runs — so only the type matters.
    static var module: Bundle { .main }
}
