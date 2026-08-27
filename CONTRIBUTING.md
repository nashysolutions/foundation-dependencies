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
as a local problem rather than a red pull request. The version CI enforces is
`minimum-swift-version` in `.github/actions/select-swift-toolchain/action.yml`,
which is the copy that has to change if the floor ever moves.

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
`UserDefaultsClient` throws, so reporting the refusal through an error is
not available. Dropping them to widen a range that only affects contributors
would trade real protection for nothing an adopter can observe.

## Where a Swift example is checked, and where it is not

Every `swift` fence in this repository is compiled by
`Scripts/check-documentation-examples.swift`, and CI runs it on every pull
request. A fence that stops compiling fails the build, which is the whole reason
the script exists: issues #27 and #30 were both published examples that had
quietly stopped working, and a person found each of them rather than a gate did.

Three places are read:

- `README.md`.
- Every `.md` file under `Sources/FoundationDependencies/Documentation.docc`.
- The `///` doc comments in every `.swift` file under `Sources`.

Three places are **not**, so an example written in one of them is unchecked.
This is the whole list, and it is deliberately short:

- **`Tests/`.** A doc comment there is a note to a contributor. It is not
  published, it reaches neither the DocC output nor Quick Help, and the file
  around it is compiled by `swift test` anyway.
- **Ordinary `//` comments, anywhere.** An implementation note is not a claim
  the package publishes.
- **Markdown other than the two entries above, including this page.** The
  fences here are `text` and `bash`, which is what keeps that true.

Writing an example in one of those places is not forbidden. Reading a green CI
run as though it vouched for one is the mistake, and this list exists so that
the difference is something you can look up rather than something you have to
notice.

One shape fails rather than going quietly unread: a `swift` fence inside a
`/** */` doc comment. Every doc comment in this package uses `///`, so the
script reads that form and reports the other, rather than shipping a
marker-stripping rule that no fence in the package exercises.

## What a documentation example has to stand on its own

Each fence is compiled by itself, so it has to name everything it uses. There
are two allowances and no others:

- A fence with no `import` line is read as an excerpt and compiled under a fixed
  prelude. A fence that imports anything at all is judged on exactly what it
  imports, which is how the missing `import SwiftUI` in #30 is caught.
- A type belonging to the reader rather than to this package, `ContentView` or
  `Settings`, comes from `Scripts/DocumentationExampleStubs.swift`. A name this
  package is supposed to export does not belong in that file: if a fence cannot
  resolve one, either the fence or the package is wrong.

Everything else is written out. A doc comment whose example elides the
`@Dependency(\.userDefaultsClient) var userDefaults` line above it does not
compile, and de-eliding it is the fix rather than an exemption. That has been
measured twice here, in #40 and again in #54, and both times the de-elided
example was also the better one to read.
