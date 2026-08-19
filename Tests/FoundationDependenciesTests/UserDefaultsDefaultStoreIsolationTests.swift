//
//  UserDefaultsDefaultStoreIsolationTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import Dependencies
import FoundationDependencies

/// Covers the store a case gets when it installs none of its own.
///
/// A case that never calls `withDependencies` still resolves a store, and the two things it
/// needs from that store pull in opposite directions. Across cases it has to be a different
/// store each time, or a value written by one case is still sitting there for the next one.
/// Within a case it has to be the same store every time, or a case that writes through one
/// resolution and reads through another gets nothing back.
///
/// Only the first of those is the reported defect, but a fix that satisfies it and breaks
/// the second would still pass a build and would still pass every other case in this target,
/// because nothing else here resolves the dependency at all. Both are asserted.
///
/// Every assertion is a write and a read rather than a comparison of instance identity.
/// Identity is a fact about the store being a class, and the interface is expected to become
/// a struct of closures, at which point an identity assertion would be measuring the box
/// rather than the store. A write that is or is not visible later means the same thing under
/// either shape.
@Suite("Default store isolation")
struct UserDefaultsDefaultStoreIsolationTests {

    /// One half of the pair described on ``sharedProbeKey``.
    @MainActor
    @Test("A case installing no store of its own starts with an empty one, first of a pair")
    func firstOfThePairStartsWithAnEmptyStore() {
        expectAnEmptyDefaultStoreThenWrite(marker: "written by the first of the pair")
    }

    /// The other half of the pair described on ``sharedProbeKey``.
    @MainActor
    @Test("A case installing no store of its own starts with an empty one, second of a pair")
    func secondOfThePairStartsWithAnEmptyStore() {
        expectAnEmptyDefaultStoreThenWrite(marker: "written by the second of the pair")
    }

    /// The requirement pulling the other way from the pair above.
    ///
    /// A caller writes through one resolution and reads through another all the time, because
    /// `@Dependency` resolves on each access rather than holding what it was given. Handing
    /// out a new store per resolution would satisfy the pair above perfectly and would leave
    /// this case reading back nothing.
    @MainActor
    @Test("Resolving twice inside one case reaches the same store")
    func resolvingTwiceInsideOneCaseReachesTheSameStore() {
        let key = "default-store-isolation.stability"
        let written = "written through the first resolution"

        let first = defaultStore()
        first.setString(written, key)
        let second = defaultStore()

        #expect(
            second.string(key) == written,
            """
            A second resolution inside one case did not see a write made through the first, \
            so the default is handing out a new store every time it is asked rather than once \
            per case. A caller that stores a value and reads it back would get nothing, and \
            nothing would fail to build.
            """
        )
    }
}

/// The key both halves of the pair write, and the reason they are a pair rather than one case.
///
/// One shared key rather than one each, because a fresh store means a case cannot see the
/// other case's write. Swift Testing does not promise which of the two runs first, and it does
/// not need to: whichever runs second is the one that finds the value when the default is
/// shared, and the one that runs first sees an empty store and passes either way. That
/// asymmetry is inherent to measuring bleed rather than a gap in the pair, since nothing has
/// leaked yet at the moment the first case looks.
private let sharedProbeKey = "default-store-isolation.probe"

/// How many cases are inside ``expectAnEmptyDefaultStoreThenWrite(marker:sourceLocation:)`` at
/// once.
///
/// The pair detects bleed by having each case read the shared key before writing it, so
/// whichever runs second is the one that sees the other's write. That only works while the two
/// cannot overlap. If both read before either writes, both find nothing and the pair reports a
/// pass whether or not the default is shared.
///
/// They cannot overlap today because both are synchronous `@MainActor` bodies, so a case holds
/// the main actor from its read through to its write. That is a property of how they are
/// written rather than one the type system enforces, so it is checked here rather than assumed.
/// Adding an `await` to either body would break it, and this turns that into a failure naming
/// the cause instead of a regression test that has quietly stopped measuring anything.
///
/// Removing `@MainActor` from either body would break it just as thoroughly. The annotation is
/// carrying the serialisation on its own now that the store endpoints are nonisolated, where it
/// used to look like something the endpoints demanded, so it is not the leftover it resembles.
@MainActor
private var casesInsideTheProbe = 0

/// Requires the default store to be empty at the point this case reaches it, then leaves
/// `marker` behind for whichever case runs next.
///
/// `sourceLocation` is threaded through so a failure points at the calling case rather than at
/// this function.
@MainActor
private func expectAnEmptyDefaultStoreThenWrite(
    marker: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    casesInsideTheProbe += 1
    defer { casesInsideTheProbe -= 1 }

    #expect(
        casesInsideTheProbe == 1,
        """
        Two cases were inside this probe at the same time, so both could read the shared key \
        before either wrote it and the pair would report a pass whichever store it was handed. \
        See the note on casesInsideTheProbe for the rule that keeps them apart.
        """,
        sourceLocation: sourceLocation
    )

    let store = defaultStore()

    #expect(
        store.string(sharedProbeKey) == nil,
        """
        This case installed no store of its own and still found a value waiting under \
        \(sharedProbeKey), so it was handed the store its sibling case had already written to. \
        Any consumer leaning on the default carries state from whichever case ran before it, \
        and which case that is changes with test order and parallelism.
        """,
        sourceLocation: sourceLocation
    )

    store.setString(marker, sharedProbeKey)
}

/// Resolves the store a caller gets when it has installed none.
///
/// This is the one place in the file that says how the dependency is reached, so the cases
/// above stay written in terms of what a store does. The interface is expected to be reshaped,
/// and when it is, this signature and this body are the only lines here that have to move.
///
/// The key form rather than `@Dependency(\.userDefaultsClient)`, because the key path form
/// warns under `-strict-concurrency=complete` for the reason set out on `Logger.init(category:)`
/// in the Log module. Both routes read the same stored value.
@MainActor
private func defaultStore() -> any UserDefaultsStoreProtocol {
    @Dependency(UserDefaultsKey.self) var store
    return store
}
