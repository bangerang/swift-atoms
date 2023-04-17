import Foundation
import CustomDump

/// `AtomStore` is responsible for injecting mutation closures into the store and enabling logging for `Atom` operations. It provides a shared singleton instance for convenient access throughout your application.
public struct AtomStore {
    
    /// Specifies the logging scope for `AtomStore` debugging purposes.
    ///
    /// Cases:
    ///   - include([any ReadableAtom]): Enables logging for the specified `ReadableAtom` instances.
    ///   - exclude([any ReadableAtom]): Disables logging for the specified `ReadableAtom` instances.
    public enum DebugScope {
        case include([any ReadableAtom])
        case exclude([any ReadableAtom])
    }
    
    var debugScope: DebugScope? = nil
    
    /// The shared singleton instance of `AtomStore`.
    public static var shared = AtomStore()
    
    /// A Boolean value that indicates whether logging is enabled for `Atom` operations. Defaults to `false`.
    public var loggingEnabled = false
    
    /// Injects a mutation closure for a given `ReadableAtom` into the store.
    ///
    /// - Parameters:
    ///   - readableAtom: A `ReadableAtom` instance whose value will be mutated by the provided closure.
    ///   - mutation: A closure that returns the new value for the `ReadableAtom`.
    ///
    /// - Returns: The modified `AtomStore` with the mutation closure injected.
    @discardableResult
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
    /// - Returns: The modified store with the logging setting applied.
    /// ```
    @MainActor
     public mutating func enableAtomLogging(_ debugScope: AtomStore.DebugScope? = nil, enabled: Bool = true) -> Self {
        self.debugScope = debugScope
        self.loggingEnabled = enabled
        return self
    }
    
    /// Logs the value change of a `ReadableAtom` if the logging is enabled and the `ReadableAtom` is in the defined debug scope.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the `ReadableAtom`.
    ///   - value: The current value of the `ReadableAtom`.
    ///
    /// This method is called internally and should not be used directly.
    @MainActor
    func logValue<T>(for id: UUID, value: T) {
#if DEBUG
        let isInScope: Bool = {
            guard let debugScope else {
                return true
            }
            switch debugScope {
            case .include(let atoms):
                return atoms.contains(where: { $0.id == id })
            case .exclude(let atoms):
                return !atoms.contains(where: { $0.id == id })
            }
        }()
        if loggingEnabled, isInScope {
            let store = StoreConfig.store
            if let debugInfo = store.debugInfo[id] {
                var string = ""
                customDump(value, to: &string)
                print("Value for \(debugInfo.name) changed:", string)
            }
        }
#endif
    }
}
