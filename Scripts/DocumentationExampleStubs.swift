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
//  Three rules keep this file from quietly weakening the gate it supports.
//
//  First, only add a declaration here when the name genuinely belongs to the
//  reader. A name this package is supposed to export belongs in `Sources`; if
//  a fence cannot resolve one, that is the fence or the package being wrong,
//  and stubbing it here would hide exactly the defect the gate exists to find.
//
//  Second, these stubs are held to the same concurrency rules as the fences
//  they support. This file is compiled alongside every fence, so a diagnostic
//  raised here is raised against all of them: under complete checking a
//  non-`Sendable` global here failed all twenty-nine fences at once, and the
//  report named the stub rather than the example, which is a gate that cannot
//  be read. The reader's stand-in types are therefore `Sendable`, which is
//  also what a reader in the Swift 6 language mode would have to write.
//
//  Third, Swift resolves `import` per file, not per module. This file imports
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
///
/// `Sendable` because it is stateless and crosses an isolation boundary in the
/// fences that use it. A final class with no stored properties satisfies the
/// conformance without `@unchecked`, so nothing is being asserted here that
/// the compiler is not checking.
final class MyService: Sendable {}

/// The two collaborators in the dependency-scoping article. Both are reference
/// types for the same reason `MyService` is, and `Sendable` for the same
/// reason it is.
final class ItemA: Sendable {}

/// The second collaborator in the dependency-scoping article.
final class ItemB: Sendable {}

/// The instance the scoping article's second fence inherits dependencies from.
///
/// The first fence in that article does build an `itemA` — issue #40 de-elided
/// it, and it now type-checks — but the second fence cannot reach it. The
/// cross-fence resolver indexes declarations, not bindings, and widening it to
/// index top-level bindings was measured and rejected: six fences across two
/// articles open with `let store`, so any fence mentioning `store` would drag
/// all six in and fail on the redeclarations. This binding is therefore not a
/// stand-in for something uncheckable; it is the price of a resolver that is
/// deliberately narrow, and it costs nothing, because the type it supplies is
/// the same `ItemA` the first fence produces.
let itemA = ItemA()

/// A `Codable` value of the reader's own, named by the `decode` and `encode`
/// examples in `UserDefaultsClient+Codable.swift`.
///
/// It belongs here rather than in `Sources` because it is the reader's model
/// type, not one this package exports: the whole point of those two methods is
/// that they take whatever `Codable` type the caller already has.
///
/// `Sendable` for the reason the types above are, and `Equatable` because it
/// costs nothing and is what a reader's settings type would be.
struct Settings: Codable, Sendable, Equatable {

    var theme = "dark"
}

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
