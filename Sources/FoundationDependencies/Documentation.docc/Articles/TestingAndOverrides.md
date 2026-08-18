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

`userDefaultsClient` is the exception. It is typed as a protocol whose operations are read-only properties, so a store cannot have one endpoint swapped out. Seed a `UserDefaultsTestStore` instead, as described in <doc:UserDefaultsClient>.

## Shared Overrides

Override for all tests in a test case:

```swift
override func invokeTest() {
    var bundle = MainBundleClientKey.testValue
    bundle.extractName = { "Test App" }

    withDependencies {
        $0.mainBundleClient = bundle
    } operation: {
        super.invokeTest()
    }
}
```
