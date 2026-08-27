# Testing and Dependency Overrides

Use `withDependencies` to override clients in your test targets.

Every client already has a test value, so a test only needs an override when it depends on particular values or particular behaviour. There is no `mock` factory: build the override from the client's test value, or construct the client directly.

## Inline Override

Each client is a struct of closures, so the least ceremonious override starts from the test value and replaces the one endpoint the test cares about:

```swift
var bundle = MainBundleClientKey.testValue
bundle.extractName = { "Test App" }

withDependencies {
    $0.mainBundleClient = bundle
} operation: {
    MyService()
}
```

`userDefaultsClient` works the same way, and used not to: its operations were read-only properties on a protocol until the interface became a struct of closures. Seeding a `UserDefaultsTestStore` is still usually the shorter route when a test only needs values in place. See <doc:UserDefaultsClient>.

## Shared Overrides

Override for all tests in a test case:

```swift
import Dependencies
import FoundationDependencies
import XCTest

final class MainBundleTests: XCTestCase {

    override func invokeTest() {
        var bundle = MainBundleClientKey.testValue
        bundle.extractName = { "Test App" }

        withDependencies {
            $0.mainBundleClient = bundle
        } operation: {
            super.invokeTest()
        }
    }
}
```
