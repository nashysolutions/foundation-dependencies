//
//  UserDefaultsClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation
import Dependencies
import DependenciesMacros
import IssueReporting

/// A type-safe interface to a `UserDefaults`-like key-value store.
///
/// This is the whole published surface. There is no protocol to conform to and no
/// second type to build: a store is a value of this type, and the two implementations
/// this package ships are reached through ``init(_:)``.
///
/// ```swift
/// @Dependency(\.userDefaultsClient) var userDefaults
///
/// userDefaults.setBool(true, forKey: "hasOnboarded")
/// let hasOnboarded = userDefaults.bool(forKey: "hasOnboarded")
/// ```
///
/// ## Endpoints and their method equivalents
///
/// Each endpoint is stored as a closure, so any one of them can be replaced on its
/// own, and each has a generated method with argument labels. Prefer the method when
/// calling, and assign to the closure when overriding:
///
/// ```swift
/// withDependencies {
///     $0.userDefaultsClient.bool = { _ in true }
/// } operation: {
///     // Everything else still behaves as the store underneath it does.
/// }
/// ```
///
/// ## The unimplemented client
///
/// `UserDefaultsClient()` builds a client whose every endpoint reports a test failure
/// when it is called. Reach for it when a test should fail if the code under test
/// touches an endpoint the test did not think about.
///
/// This is not what ``testValue`` is, and the difference is deliberate. See the note
/// there.
///
/// ``bool``, ``int`` and ``double`` are the three endpoints that report through a
/// written-out default rather than the one `@DependencyClient` generates, and the
/// duplication is load-bearing rather than untidy. The macro refuses to generate a
/// default for a non-throwing endpoint returning a non-optional, because it has
/// nothing to return after reporting, so those three have to carry one in source. An
/// endpoint that carries its own default supersedes the macro's: the default
/// initialises the private storage the macro generates, so whatever is written here
/// is what an unimplemented client runs, and the macro's reporting version is never
/// reached.
///
/// That was measured, not assumed. Written as `= { _ in false }` the three read as
/// unimplemented and report nothing, so a test touching one of them silently gets a
/// plausible `false` while the other twelve fail loudly. `UserDefaultsClientOverrideTests`
/// asserts a report from one of the three and one of the twelve, so a later edit that
/// drops a `reportIssue` from here fails rather than quietly reopening the hole.
///
/// ## Concurrency
///
/// Every endpoint is a nonisolated `@Sendable` closure, so a client may be resolved
/// and called from any concurrency domain: a background task, a widget extension
/// reading an app group suite, or the main actor. No endpoint hops, and none of them
/// is `async`, so a read returns its value in the caller's own domain.
///
/// Nothing here serialises those calls. A client built over one of this package's
/// stores inherits that store's own guarantee, stated at its declaration; a client
/// assembled from closures of your own inherits nothing, so whatever those closures
/// capture has to be safe to touch from more than one at a time.
@DependencyClient
public struct UserDefaultsClient: Sendable {

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key, or `false` if there is none.
    public var bool: @Sendable (_ forKey: String) -> Bool = { _ in
        reportIssue("Unimplemented: '\(Self.self).bool'")
        return false
    }

    /// Retrieves an integer value for the specified key, or `0` if there is none.
    public var int: @Sendable (_ forKey: String) -> Int = { _ in
        reportIssue("Unimplemented: '\(Self.self).int'")
        return 0
    }

    /// Retrieves a double value for the specified key, or `0` if there is none.
    public var double: @Sendable (_ forKey: String) -> Double = { _ in
        reportIssue("Unimplemented: '\(Self.self).double'")
        return 0
    }

    /// Retrieves a string value for the specified key, or `nil` if there is none.
    public var string: @Sendable (_ forKey: String) -> String?

    /// Retrieves an array of strings for the specified key, or `nil` if there is none.
    public var stringArray: @Sendable (_ forKey: String) -> [String]?

    /// Retrieves a raw object for the specified key, or `nil` if there is none.
    public var object: @Sendable (_ forKey: String) -> Any?

    /// Retrieves a `Date` value for the specified key, or `nil` if there is none.
    public var date: @Sendable (_ forKey: String) -> Date?

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @Sendable (Bool, _ forKey: String) -> Void

    /// Stores an integer value for the specified key.
    public var setInt: @Sendable (Int, _ forKey: String) -> Void

    /// Stores a double value for the specified key.
    public var setDouble: @Sendable (Double, _ forKey: String) -> Void

    /// Stores a string value for the specified key, or removes it when `nil`.
    public var setString: @Sendable (String?, _ forKey: String) -> Void

    /// Stores an array of strings for the specified key, or removes it when `nil`.
    public var setStringArray: @Sendable ([String]?, _ forKey: String) -> Void

    /// Stores a raw object for the specified key, or removes it when `nil`.
    public var setObject: @Sendable (Any?, _ forKey: String) -> Void

    /// Stores a `Date` value for the specified key, or removes it when `nil`.
    public var setDate: @Sendable (Date?, _ forKey: String) -> Void

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    public var removeObject: @Sendable (_ forKey: String) -> Void

    // MARK: - Building One Over a Store

    /// Creates a client backed by the app's own defaults or by a named suite.
    ///
    /// ```swift
    /// $0.userDefaultsClient = UserDefaultsClient(.standard)
    /// ```
    ///
    /// - Parameter store: The live store to route every endpoint through.
    public init(_ store: UserDefaultsLiveStore) {
        self.init(routingThrough: store)
    }

    /// Creates a client backed by an in-memory store, for tests and previews.
    ///
    /// - Parameter store: The test store to route every endpoint through. Hold on to
    ///                    it if the test needs to seed or inspect it; the client keeps
    ///                    it alive either way.
    public init(_ store: UserDefaultsTestStore) {
        self.init(routingThrough: store)
    }

    /// Routes every endpoint through `store`.
    ///
    /// The two public initialisers above are thin wrappers over this one so that the
    /// fifteen-line mapping is written once. It is generic rather than taking the
    /// protocol existentially because ``UserDefaultsStore`` is internal, and a public
    /// initialiser cannot name it.
    private init<Store: UserDefaultsStore>(routingThrough store: Store) {
        self.init(
            bool: { store.bool(forKey: $0) },
            int: { store.int(forKey: $0) },
            double: { store.double(forKey: $0) },
            string: { store.string(forKey: $0) },
            stringArray: { store.stringArray(forKey: $0) },
            object: { store.object(forKey: $0) },
            date: { store.date(forKey: $0) },
            setBool: { store.setBool($0, forKey: $1) },
            setInt: { store.setInt($0, forKey: $1) },
            setDouble: { store.setDouble($0, forKey: $1) },
            setString: { store.setString($0, forKey: $1) },
            setStringArray: { store.setStringArray($0, forKey: $1) },
            setObject: { store.setObject($0, forKey: $1) },
            setDate: { store.setDate($0, forKey: $1) },
            removeObject: { store.removeObject(forKey: $0) }
        )
    }
}

// MARK: - Dependency Registration

extension UserDefaultsClient: TestDependencyKey {

    /// The client a caller gets when it has installed none of its own.
    ///
    /// A working in-memory store rather than the unimplemented client
    /// `UserDefaultsClient()` produces, which is the opposite of what this package's
    /// other clients do and is deliberate. Storage is the kind of dependency a test
    /// uses incidentally, as when code under test writes a flag and reads it back three
    /// lines later, and a default that failed on the first touch would make every such
    /// test register a store before it could say anything. `UserDefaultsClient()` is still
    /// there for the tests that do want that, and is one assignment away.
    ///
    /// Computed rather than stored, and it has to stay that way. ``UserDefaultsTestStore``
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
    public static var testValue: UserDefaultsClient {
        UserDefaultsClient(UserDefaultsTestStore())
    }
}

/// Extension for registering and accessing the user defaults client in the dependency
/// injection system.
public extension DependencyValues {

    /// The user defaults client available in the current dependency context.
    ///
    /// Use this to access or override the user defaults client for testing.
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
