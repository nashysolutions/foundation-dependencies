# Contributing

## Running the test suite

The test suite needs Swift 6.2 or newer. Nothing older can compile `Tests/`.

`Tests/FoundationDependenciesTests/UserDefaultsStoreTrapTests.swift` asserts that
storing a value `UserDefaults` cannot hold ends the process. Swift Testing's exit
tests, `#expect(processExitsWith:)`, are the only way to assert that, and they
arrived in Swift 6.2.

On an older toolchain the failure names no version, which is the reason this page
exists. The macro does not recognise the `processExitsWith:` argument, so it reads
the call as an ordinary boolean expectation and reports that instead:

```text
error: extra trailing closure passed in macro expansion
error: type 'Bool' has no member 'failure'
```

Nothing is wrong with the test file when you see this. Check the toolchain first:

```bash
swift --version
```

CI selects a qualifying toolchain itself and fails with a message naming the
requirement when no Xcode on the runner provides one, so an unmet floor shows up
as a local problem rather than a red pull request.

## The floor binds contributors, not consumers

Depending on this package requires no particular Swift version beyond what
`Package.swift` already declares. The section above is not a supported toolchain
range, and it should not be repeated anywhere that an adopter reads as one.

The requirement lives entirely in the test target, and SwiftPM does not build a
dependency's test target. Nothing under `Sources/` uses an API newer than the
manifest implies, so the code that needs 6.2 is never handed to the compiler of
anyone who depends on this package. The floor binds people who run the suite,
which means contributors and CI. It does not bind people who ship against the
library.

That split is a property of where the code sits, not a guarantee. Putting a
6.2-era API into `Sources/` would move the floor onto consumers and quietly make
this section wrong, so treat it as a reason to keep such APIs in `Tests/`.

The split also rules out one tempting fix. The exit tests are the only coverage
proving that both stores really do trap on a non-property-list value rather than
silently accepting it, and they exist because no endpoint on
`UserDefaultsStoreProtocol` throws, so reporting the refusal through an error is
not available. Dropping them to widen a range that only affects contributors
would trade real protection for nothing an adopter can observe.
