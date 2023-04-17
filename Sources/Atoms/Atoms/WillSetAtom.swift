import Foundation

/// A generic structure that conforms to the `WritableAtom` and `ResettableAtom` protocols.
///
/// Use `WillSetAtom` to store values of type `T` and perform custom logic before updating the stored value. It provides a closure that is called before the stored value is updated.
///
/// Example:
///
/// ```swift
/// let lowercasedAtom = WillSetAtom("", willSet: { newValue in
///     return newValue.lowercased()
/// })
///
/// struct ContentView: View {
///     @UseAtom(lowercasedAtom) var inputValue
///
///     var body: some View {
///         VStack {
///             TextField("Enter text", text: $inputValue)
///             Text("Lowercased: \(inputValue)")
///         }
///         .padding()
///     }
/// }
/// ```
///
/// `WillSetAtom` is also resettable, meaning that you can reset its value to its initial value, optionally running a custom reset closure.

public struct WillSetAtom<T>: WritableAtom, ResettableAtom {
    
    /// The type of the value wrapped in the `WillSetAtom`.
    public let type: T.Type
    /// A unique identifier for the `WillSetAtom`.
    public let id: UUID
    /// A flag indicating if the `WillSetAtom` should be kept alive.
    public let keepAlive: Bool
    
    private let initialValue: T
    private let setup: @MainActor () -> Void

    /// Initializes a new instance of `WillSetAtom`.
    ///
    /// Use this initializer to store values of type `T` and perform custom logic before updating the stored value. It provides a closure that is called before the stored value is updated.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean value indicating if the `WillSetAtom` should be kept alive.
    ///   - file: The file where the `WillSetAtom` is created. Defaults to the current file.
    ///   - function: The function where the `WillSetAtom` is created. Defaults to the current function.
    ///   - line: The line where the `WillSetAtom` is created. Defaults to the current line.
    ///   - initialValue: A closure that returns the initial value of the `WillSetAtom`.
    ///   - willSet: A closure that is called before updating the stored value. It receives the new value and returns the updated value.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, _ initialValue: @escaping @autoclosure () -> T, willSet: @escaping (T) -> T) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.type = T.self
        self.initialValue = initialValue()
        self.setup = {
            let initialValue = initialValue()
            _ = findObservables(using: id) {
                let atom = AtomValue(initialValue, id: id)
                _ = willSet(initialValue)
                let store = StoreConfig.store
                store.addAtomValue(atom, for: id)
                setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
                atom.customSet = { newValue in
                    atom._value = willSet(newValue)
                }
                return atom
            } observedChanged: { (atom: AtomValue<T>) in
                atom.value = atom.value
            }
        }
        atomConfigurations[id] = setup
    }

    /// Resets the value of the `WillSetAtom` to its initial value, optionally running a custom reset closure.
    ///
    /// Use this method to reset the value of the `WillSetAtom` to its initial value, optionally running a custom reset closure.
    public func reset() {
        Task { @MainActor in
            let store = StoreConfig.store
            
            guard let atom: AtomValue<T> = store.getAtomValue(for: id) else {
                return
            }
            
            var value = initialValue
            
            if let onReset = store.resettableCallbacks[id] as? (inout T) -> Void {
                onReset(&value)
            }
            
            atom._value = value
        }

    }
}
