//
//  UserDefaultsStoreTrapTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// The suite the live cases write to.
///
/// It is deliberately not the shared scratch suite the contract cases use. The cases
/// below are `async`, so each is suspended while its child process runs and other
/// cases are free to run in the meantime; emptying the shared suite from here could
/// wipe a contract case's keys underneath it. A name of its own removes the question.
private let trapSuiteName = "foundation-dependencies.contract.trap"

/// Empties the trap suite.
private func emptyTrapSuite() {
    UserDefaults(suiteName: trapSuiteName)?.removePersistentDomain(forName: trapSuiteName)
}

/// That no write can end the process.
///
/// This suite used to assert the opposite for one endpoint. `setObject` took `Any?`,
/// and `UserDefaults` raises `NSInvalidArgumentException` when handed a value that is
/// not a property list, so the contract was that the call did not return: accepting
/// the value would have let a test pass against behaviour production does not have,
/// and returning an error was not available because no endpoint throws.
///
/// The endpoint is gone. ``PropertyListValue`` has no case for a value `UserDefaults`
/// cannot hold, so the argument that used to end the process can no longer be written,
/// and every other setter takes a concrete storable type. What is left to check is the
/// consequence: that the whole write surface, exercised against a real suite, comes
/// back. `everyWriteLeavesTheProcessAlive` is the old control case widened from one
/// endpoint to all of them, and it is the case that would redden if a trapping path
/// were reintroduced.
@Suite("Writes and the process")
struct UserDefaultsStoreTrapTests {

    @Test("Every write against a live store leaves the process alive")
    func everyWriteLeavesTheProcessAlive() async {
        await #expect(processExitsWith: .success) {
            guard let store = UserDefaultsLiveStore(suiteName: trapSuiteName) else {
                // Reported as a failure by `theTrapSuiteNameIsUsable` below rather
                // than swallowed here, where the exit status is the only channel.
                exit(EXIT_FAILURE)
            }

            store.setBool(true, forKey: "flag")
            store.setInt(42, forKey: "number")
            store.setDouble(3.5, forKey: "fraction")
            store.setString("abc", forKey: "text")
            store.setStringArray(["a", "b"], forKey: "list")
            store.setDate(Date(timeIntervalSince1970: 0), forKey: "moment")
            store.setData(Data([0x00, 0xFF]), forKey: "blob")
            store.setURL(URL(fileURLWithPath: "/tmp/a b.txt"), forKey: "location")
            store.setPropertyList(
                ["counts": [1, 2], "names": ["a"], "seen": true, "when": .date(.now)],
                forKey: "nested"
            )
            store.removeValue(forKey: "flag")
        }
        emptyTrapSuite()
    }

    /// The same against the in-memory store, which reaches the writes by a different
    /// route: it validated its argument against `PropertyListSerialization` and failed
    /// a `precondition` where the live store let `UserDefaults` raise. Both routes are
    /// gone, and both are checked.
    @Test("Every write against the test store leaves the process alive")
    func everyWriteAgainstTheTestStoreLeavesTheProcessAlive() async {
        await #expect(processExitsWith: .success) {
            let store = UserDefaultsTestStore()

            store.setBool(true, forKey: "flag")
            store.setInt(42, forKey: "number")
            store.setDouble(3.5, forKey: "fraction")
            store.setString("abc", forKey: "text")
            store.setStringArray(["a", "b"], forKey: "list")
            store.setDate(Date(timeIntervalSince1970: 0), forKey: "moment")
            store.setData(Data([0x00, 0xFF]), forKey: "blob")
            store.setURL(URL(fileURLWithPath: "/tmp/a b.txt"), forKey: "location")
            store.setPropertyList(
                ["counts": [1, 2], "names": ["a"], "seen": true, "when": .date(.now)],
                forKey: "nested"
            )
            store.removeValue(forKey: "flag")
        }
    }

    /// The control for the two cases above, and the reason they are worth running.
    ///
    /// A `.success` expectation is only evidence if the harness can report anything
    /// else. Without this case, an exit test that had stopped observing the child
    /// altogether would pass both cases above and read exactly like a package with no
    /// trapping write in it. This one ends the process on purpose and requires the
    /// failure to be seen.
    @Test("A body that does end the process is reported as a failure")
    func theExitHarnessCanReportAFailure() async {
        await #expect(processExitsWith: .failure) {
            exit(EXIT_FAILURE)
        }
    }

    /// The live case above is only meaningful if the store it tries to build can be
    /// built. If Foundation refused this suite name, that body would exit with a
    /// failure and the case would read as "a write ended the process" rather than "the
    /// store was never made".
    @Test("The suite name the live case uses is one Foundation accepts")
    func theTrapSuiteNameIsUsable() {
        #expect(UserDefaultsLiveStore(suiteName: trapSuiteName) != nil)
        emptyTrapSuite()
    }
}
