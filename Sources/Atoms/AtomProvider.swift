import SwiftUI

/// An extension to `View` that provides convenience methods for injecting mutation closures and enabling logging for `Atom` operations.
extension View {
    
    /// Injects a mutation closure for a given `ReadableAtom` into the view hierarchy.
    ///
    /// - Parameters:
    ///   - readableAtom: A `ReadableAtom` instance whose value will be mutated by the provided closure.
    ///   - mutation: A closure that returns the new value for the `ReadableAtom`.
    ///
    /// - Returns: The modified view with the mutation closure injected into the view hierarchy.
    ///
    /// Usage:
    ///
    /// ```swift
    /// Text("Hello, World!")
    ///     .inject(counterAtom, mutation: { newValue })
    /// ```
    @MainActor
    public func inject<R: ReadableAtom>(_ readableAtom: R, mutation: @escaping () -> R.T) -> Self {
        StoreConfig.store.inject(readableAtom, mutation: mutation)
        return self
    }
    
    /// Enables or disables logging for `Atom` operations.
    ///
    /// - Parameters:
    ///   - debugScope: An optional `AtomStore.DebugScope` value to specify the logging scope. Defaults to `nil`.
    ///   - enabled: A Boolean value that indicates whether logging should be enabled (`true`) or disabled (`false`). Defaults to `true`.
    ///
    /// - Returns: The modified view with the logging setting applied.
    ///
    /// Usage:
    ///
    /// ```swift
    /// Text("Hello, World!")
    ///     .enableAtomLogging(debugScope: .include([counterAtom]))
    /// ```
    @MainActor
    public func enableAtomLogging(_ debugScope: AtomStore.DebugScope? = nil, enabled: Bool = true) -> Self {
        AtomStore.shared.debugScope = debugScope
        AtomStore.shared.loggingEnabled = enabled
        return self
    }
}
