import Foundation
import SwiftUI
import Combine

/// A property wrapper that provides read-only access to the atom's value, and it's reactive to changes.
///
/// Usage:
///
/// ```swift
/// let textAtom = Atom("Hello")
/// let derivedAtom = DerivedAtom {
///     @UseAtomValue(textAtom) var text
///     return text.count
/// }
///
/// struct ContentView: View {
///     @UseAtom(textAtom) var text
///     @UseAtomValue(derivedAtom) var derived
///     var body: some View {
///         TextField("", text: $text)
///         Text("\(derived)")
///     }
/// }
/// ```
///
@propertyWrapper
public struct UseAtomValue<T>: DynamicProperty {
    
    /// The current value of the wrapped `WritableAtom`.
    public var wrappedValue: T {
        return atom.value
    }
    
    @ObservedObject private var atom: AtomValue<T>
    private var refCounter: RefCounter? = nil
    
    /// Initializes a new `UseAtomValue` instance for the given `ReadableAtom`.
    ///
    /// - Parameters:
    ///   - readableAtom: A `ReadableAtom` instance whose value will be managed by the `UseAtomValue`.
    ///   - debounce: An optional time interval for debouncing the value updates. Default is `0`.
    public init<R: ReadableAtom>(_ readableAtom: R, debounce: TimeInterval = 0) where R.T == T {
        readableAtom.runSetupIfNeeded()
        let store = StoreConfig.store
        if !readableAtom.keepAlive {
            if Scope.id == defaultScopeID {
                refCounter = RefCounter(id: readableAtom.id)
            } else {
                store.watchCount.mutate { value in
                    value[readableAtom.id, default: 0] += 1
                }
            }
        }
        let atom: AtomValue<T> = store.getAtomValue(for: readableAtom.id)
        _atom = .init(wrappedValue: atom)
        store.usedAtoms[Scope.id, default: []].append(.init(scope: Scope.id,
                                                            atom: readableAtom.id,
                                                            watching: true,
                                                            debounced: debounce,
                                                            keepAlive: readableAtom.keepAlive))
        usedAtomsSubject.send(.init(scope: Scope.id,
                                    atom: readableAtom.id,
                                    watching: true,
                                    debounced: debounce,
                                    keepAlive: readableAtom.keepAlive))
    }
}
