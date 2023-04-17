import Foundation

/// A generic `DerivedAtom` represents a derived state for a given value of type `T`.
///
/// `DerivedAtom` manages a read-only state derived from other atom states. The derived state is automatically updated
/// when any of its dependencies change.
///
/// Example:
///
/// ```swift
/// let usernameAtom = Atom("John Doe")
/// let greetingAtom = DerivedAtom {
///     @UseAtomValue(usernameAtom) var username
///     return "Hello, \(username)!"
/// }
///
/// struct ContentView: View {
///     @UseAtom(usernameAtom) var username
///     @UseAtomValue(greetingAtom) var greeting
///
///     var body: some View {
///         VStack {
///             Text(greeting)
///             TextField("Update user", text: $username)
///                 .padding()
///                 .textFieldStyle(.rounded)
///         }
///     }
/// }
/// ```
///
/// Conforms to the `ReadableAtom` protocol.
public struct DerivedAtom<T>: ReadableAtom {
    /// The type of the value managed by the derived atom.
    public let type: T.Type
    /// A unique identifier for the derived atom.
    public let id: UUID
    /// A boolean indicating whether the derived atom should be kept alive in memory.
    public let keepAlive: Bool
    
    private let setup: @MainActor () -> Void
    
    /// Creates a `DerivedAtom` with a closure that computes the derived value.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean indicating whether the derived atom should be kept alive in memory.
    ///   - file: The file where the derived atom is declared.
    ///   - function: The function where the derived atom is declared.
    ///   - line: The line number where the derived atom is declared.
    ///   - get: A closure that computes the derived value based on other atom values.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, get: @MainActor @escaping () -> T) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.type = T.self
        self.setup = {
            _ = findObservables(using: id) {
                let atom = AtomValue(get(), id: id)
                let store = StoreConfig.store
                store.addAtomValue(atom, for: id)
                setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
                return atom
            } observedChanged: { atom in
                atom.value = get()
            }
        }
        atomConfigurations[id] = setup
    }
}
