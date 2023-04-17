import SwiftUI
import CustomDump

/// An `ObservableObjectAtom` represents a readable state for a given value of type `T` that conforms to `ObservableObject`.
///
/// `ObservableObjectAtom` wraps a value of type `T` and updates the state when the wrapped object's `objectWillChange`
/// publisher sends an event.
///
/// This can be used for more advanced state management, as it allows you to handle state inside the `ObservableObject`
///
/// Usage:
///
/// ```swift
/// class Counter: ObservableObject {
///     @Published var value: Int = 0
/// }
///
/// let myCounter = Counter()
/// let myCounterAtom = ObservableObjectAtom(myCounter)
///
/// struct ContentView: View {
///     @UseAtomValue(myCounterAtom) var counter
///
///     var body: some View {
///         VStack {
///             Text("Counter: \(counter.value)")
///             Button("Increment") {
///                 counter.value += 1
///             }
///         }
///     }
/// }
/// ```
public struct ObservableObjectAtom<T: ObservableObject>: ReadableAtom {
    /// The type of the value managed by the atom.
    public let type = T.self
    /// A unique identifier for the atom.
    public let id: UUID
    /// A boolean indicating whether the atom should be kept alive in memory.
    public let keepAlive: Bool
    
    private let setup: @MainActor () -> Void
    
    /// Creates an `Atom` with a default value.
    ///
    /// - Parameters:
    ///   - object: The observable object for the atom.
    ///   - keepAlive: A boolean indicating whether the atom should be kept alive in memory.
    ///   - file: The file where the atom is declared.
    ///   - function: The function where the atom is declared.
    ///   - line: The line number where the atom is declared.
    public init(_ object: T, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.setup = {
            let atom = AtomValue(object, id: id)
            let store = StoreConfig.store
            store.addAtomValue(atom, for: id)
            object.objectWillChange.sink { _ in
            } receiveValue: { _ in
                Task { @MainActor in
                    if let atomValue: AtomValue<T> = store.getAtomValue(for: id) {
                        AtomStore.shared.logValue(for: id, value: object)
                        atomValue.objectWillChange.send()
                    }
                }
            }.store(in: &StoreConfig.store.cancellables[id, default: []])
        }
        atomConfigurations[id] = setup
        setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
    }
}
