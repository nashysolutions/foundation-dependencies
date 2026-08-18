//
//  UserDefaultsStoreTrapTests.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 18/08/2026.
//

import Foundation
import Testing
import FoundationDependencies

/// The suite the live trap case writes to.
///
/// It cannot carry a UUID like the other live cases do. An exit test body runs in a
/// fresh process and may not capture anything from the parent, so the name has to be a
/// constant both sides already know. Nothing is ever stored under it: the call being
/// made is the one that ends the process.
let trapSuiteName = "foundation-dependencies.contract.trap"

/// A value `UserDefaults` does not accept.
///
/// `URL` is the one a caller is most likely to reach for by accident, because
/// `UserDefaults` does have a dedicated `set(_:forKey:)` overload that takes one. That
/// overload is not this endpoint: `setObject` takes `Any?`, which binds to the
/// property list path, and the property list path rejects a `URL`.
func nonPropertyListValue() -> Any {
    URL(fileURLWithPath: "/tmp")
}

/// What every conformer must do when asked to store a value `UserDefaults` cannot
/// hold.
///
/// The contract is that the call does not return. Accepting the value would let a test
/// pass against behaviour production does not have, and returning an error is not
/// available: no endpoint on the protocol throws.
///
/// The assertion is deliberately "the process did not exit successfully" rather than a
/// particular signal, because the two stores get there by different routes and both
/// routes are correct. Measured on macOS arm64, Swift 6.2.4: the live store raises
/// `NSInvalidArgumentException`, which aborts with signal 6, and the test store fails a
/// `precondition`, which traps with signal 5. Pinning either number would pin an
/// implementation detail the protocol does not promise, and would fail the other store.
@Suite("Storing a value UserDefaults cannot hold")
struct UserDefaultsStoreTrapTests {

    @Test("The live store ends the process")
    func liveStoreEndsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                guard let store = UserDefaultsLiveStore(suiteName: trapSuiteName) else {
                    return
                }
                store.setObject(nonPropertyListValue(), "key")
            }
        }
        removeScratchSuite(named: trapSuiteName)
    }

    @Test("The test store ends the process")
    func testStoreEndsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let store = UserDefaultsTestStore()
                store.setObject(nonPropertyListValue(), "key")
            }
        }
    }

    /// The control for the two cases above.
    ///
    /// Without it, a body that crashed for some unrelated reason, or a harness that
    /// reported failure whatever happened, would look exactly like a store correctly
    /// refusing the value. This runs the same endpoint with a value `UserDefaults` does
    /// accept and requires the process to survive, so a failure result from the other
    /// two cases means something.
    @Test("A property list value through the same endpoint leaves the process alive")
    func aValidValueLeavesTheProcessAlive() async {
        await #expect(processExitsWith: .success) {
            await MainActor.run {
                let store = UserDefaultsTestStore()
                store.setObject("abc", "key")
            }
        }
    }

    /// The live case above is only meaningful if the store it tries to build can be
    /// built. If Foundation refused this suite name, that body would return early and
    /// exit successfully, and the failure would read as "the store did not trap" rather
    /// than "the store was never made".
    @Test("The suite name the live case uses is one Foundation accepts")
    func theTrapSuiteNameIsUsable() {
        #expect(UserDefaultsLiveStore(suiteName: trapSuiteName) != nil)
        removeScratchSuite(named: trapSuiteName)
    }
}
