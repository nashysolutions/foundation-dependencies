# Scoping Dependencies

Dependency resolution is context-sensitive. Construct dependency-using objects **inside** the `withDependencies` scope.

## Incorrect

```swift
let itemA = withDependencies { ... } operation: { ItemA() }
let itemB = ItemB() // Will use testValue unexpectedly
```

## Correct

```swift
let itemB = withDependencies(from: itemA) {
    ItemB()
}
```

## Single-Entry-Point Systems

In SwiftUI apps, most objects are constructed inside a root dependency scope, like App or SceneDelegate.
But even here, you can scope overrides using .environment(...) or withDependencies { ... }.

```swift
.environment(\.colorScheme, .dark)
```
