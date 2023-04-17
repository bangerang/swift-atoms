import Foundation
import SwiftUI

/// A property wrapper that provides read and write access to the atom's value, and it's reactive to changes.
///
/// Usage:
///
/// Usage:
///
/// ```swift
/// let textAtom = Atom("Hello")
///
/// struct ContentView: View {
///     @UseAtom(textAtom) var text
///     var body: some View {
///         TextField("", text: $text)
///     }
/// }
/// ```
///
@propertyWrapper
public struct UseAtom<T>: DynamicProperty {
    
    /// The current value of the wrapped `WritableAtom`.
    public var wrappedValue: T {
        get {
            return atom.value
        } nonmutating set {
            atom.value = newValue
        }
    }
    
    /// A `Binding` to the value of the wrapped `WritableAtom`.
    public var projectedValue: Binding<T> {
        return $atom.value
    }
    
    @ObservedObject private var atom: AtomValue<T>
    private var refCounter: RefCounter? = nil
    
    /// Initializes a new `UseAtom` instance for the given `WritableAtom`.
    ///
    /// - Parameters:
    ///   - writableAtom: A `WritableAtom` instance whose value will be managed by the `UseAtom`.
    ///   - debounce: An optional time interval for debouncing the value updates. Default is `0`.
    ///
    public init<W: WritableAtom>(_ writableAtom: W, debounce: TimeInterval = 0) where W.T == T {
        writableAtom.runSetupIfNeeded()
        let store = StoreConfig.store
        if !writableAtom.keepAlive {
            if Scope.id == defaultScopeID {
                refCounter = RefCounter(id: writableAtom.id)
            } else {
                store.watchCount.mutate { value in
                    value[writableAtom.id, default: 0] += 1
                }
            }
        }
        let atom: AtomValue<T> = store.getAtomValue(for: writableAtom.id)
        _atom = .init(wrappedValue: atom)
        store.usedAtoms[Scope.id, default: []].append(.init(scope: Scope.id,
                                                            atom: writableAtom.id,
                                                            watching: true, debounced: debounce,
                                                            keepAlive: writableAtom.keepAlive))
        usedAtomsSubject.send(.init(scope: Scope.id,
                                    atom: writableAtom.id,
                                    watching: true,
                                    debounced: debounce,
                                    keepAlive: writableAtom.keepAlive))
    }
}
