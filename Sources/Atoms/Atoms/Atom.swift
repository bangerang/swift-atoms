import Foundation

/// A generic `Atom` represents a state for a given value of type `T`.
///
/// `Atom` manages a mutable state for a value of type `T`.
///
/// Example:
///
/// ```swift
/// let myAtom = Atom(0)
///
/// struct ContentView: View {
///     @UseAtom(myAtom) var count
///
///     var body: some View {
///         VStack {
///             Text("Current count: \(count)")
///             TextField("Update count", value: $count, formatter: NumberFormatter())
///         }
///     }
/// }
/// ```
///
/// Conforms to the `WritableAtom` and `ResettableAtom` protocols.

public struct Atom<T>: WritableAtom, ResettableAtom {
    /// The type of the value managed by the atom.
    public let type: T.Type
    /// A unique identifier for the atom.
    public let id: UUID
    /// A boolean indicating whether the atom should be kept alive in memory.
    public let keepAlive: Bool
    
    private let defaultValue: T
    private let setup: @MainActor () -> Void
    
    /// Creates an `Atom` with a default value.
    ///
    /// - Parameters:
    ///   - defaultValue: The default value for the atom.
    ///   - keepAlive: A boolean indicating whether the atom should be kept alive in memory.
    ///   - file: The file where the atom is declared.
    ///   - function: The function where the atom is declared.
    ///   - line: The line number where the atom is declared.
    public init(_ defaultValue: T, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.type = T.self
        self.id = id
        self.defaultValue = defaultValue
        self.setup = {
            let atom = AtomValue(defaultValue, id: id)
            let store = StoreConfig.store
            store.addAtomValue(atom, for: id)
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
        }
        atomConfigurations[id] = setup
    }
    
    /// Resets the atom to its default value, optionally executing a callback.
    ///
    /// This method is useful for resetting the atom to its initial state. If a callback is registered,
    /// it will be executed before updating the atom's value.
    public func reset() {
        Task { @MainActor in
            let store = StoreConfig.store
            guard let atom: AtomValue<T> = store.getAtomValue(for: id) else {
                return
            }
            
            var value = defaultValue
            
            if let onReset = store.resettableCallbacks[id] as? (inout T) -> Void {
                onReset(&value)
            }
            
            atom.value = value
        }

    }
}
