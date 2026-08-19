# Using `mainBundleClient`

Use this dependency to access `Bundle` information safely within Swift Concurrency contexts.

```swift
@Dependency(\.mainBundleClient) var bundle

do {
    let url = try bundle.urlForResource("Localisable", "strings")
} catch {
    // Handle error
}
```

## Providing Live Values

This package ships a `testValue` and no `liveValue`, so an app that wants real
bundle values registers one. Conform a type to `XcodeBundle` and hand its
accessors to `MainBundleClient`:

```swift
final class BundleLocator: XcodeBundle {}

extension MainBundleClientKey: @retroactive DependencyKey {

    public static let liveValue: MainBundleClient = {
        let locator = BundleLocator()
        return MainBundleClient(
            urlForResource: locator.urlForResource,
            extractIdentifier: locator.extractIdentifier,
            extractName: locator.extractName,
            extractShortVersionString: locator.extractShortVersionString,
            extractBuildNumber: locator.extractBuildNumber,
            imageAsset: { BundleLocator.asset(named: $0) },
            colorAsset: { BundleLocator.color(named: $0) }
        )
    }()
}
```

`@retroactive` is required, and is not decoration. `MainBundleClientKey` belongs
to this package and `DependencyKey` belongs to `swift-dependencies`, so
declaring the conformance in your own module is a retroactive conformance and
the compiler warns without it. The same caveat applies as on
<doc:UserDefaultsClient>: if `FoundationDependencies` ever declares this
conformance itself, every consumer holding a copy of it hits a duplicate
conformance and stops compiling.

## SPM Modules

If used from within a Swift Package, provide your own bundle:

```swift
final class BundleLocator: XcodeBundle {
    static var bundle: Bundle { .module }
}
```
