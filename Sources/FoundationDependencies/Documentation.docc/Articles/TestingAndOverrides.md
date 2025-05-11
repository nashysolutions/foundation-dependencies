# Testing and Dependency Overrides

Use `withDependencies` to override clients in your test targets.

## Inline Override

```swift
withDependencies {
    $0.mainBundleClient = .mock(...)
} operation: {
    MyService()
}
```

## Shared Overrides

Override for all tests in a test case:

```swift
override func invokeTest() {
    withDependencies {
        $0.mainBundleClient = .mock(...)
    } operation: {
        super.invokeTest()
    }
}
```
