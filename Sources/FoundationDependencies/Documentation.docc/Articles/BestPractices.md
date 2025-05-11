# Best Practices

- Always provide a live value for each client in your main app.
- Use `.module` in SwiftPM targets for proper resource bundling.
- Fail loudly in tests using default `.testValue` implementations.
- Use `withDependencies(from:)` for nested scoping scenarios.
