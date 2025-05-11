# Using `mainBundleClient`

Use this dependency to access `Bundle` information safely within Swift Concurrency contexts.

```swift
@Dependency(\.mainBundleClient) var bundle

do {
    let url = try bundle.url(forResource: "Localisable", withExtension: "strings")
} catch {
    // Handle error
}
```

## Providing Live Values

```swift
final class BundleLocator: XcodeBundle {}

extension MainBundleClientKey: DependencyKey {
    public static let liveValue = MainBundleClient(
        ...
    )
}
```

## SPM Modules

If used from within a Swift Package, provide your own bundle:

```swift
final class BundleLocator: XcodeBundle {
    static var bundle: Bundle { .module }
}
```
