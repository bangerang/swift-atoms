import Foundation
import SwiftUI

/// A property wrapper that captures the atom's value and provides read-only access without being reactive to changes.
///
/// Usage:
///
/// ```swift
/// let textAtom = Atom("")
/// let derivedAtom = DerivedAtom {
///     @UseAtomValue(textAtom) var text
///     return text.count
/// }
/// let derivedAtom2 = DerivedAtom {
///     @UseAtomValue(textAtom) var text
///     @CaptureAtomValue(derivedAtom) var count
///     return "\(text) is \(count) long"
/// }
///
/// struct ContentView: View {
///     @UseAtom(textAtom) var text
///     @UseAtomValue(derivedAtom2) var derived
///     var body: some View {
///         TextField("", text: $text)
///         Text("\(derived)")
///     }
/// }
/// ```
@propertyWrapper @MainActor
public struct CaptureAtomValue<T> {
    /// The current value of the wrapped `ReadableAtom`.
    public var wrappedValue: T {
        return readOnlyAtom.value
    }
    private var refCounter: RefCounter? = nil
    private let readOnlyAtom: AtomValue<T>
    
    /// Initializes a new `CaptureAtomValue` instance for the given `ReadableAtom`.
    ///
    /// - Parameters:
    ///   - readableAtom: A `ReadableAtom` instance whose value will be managed by the `CaptureAtomValue`.
    public init<R: ReadableAtom>(_ readableAtom: R) where R.T == T {
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
        readOnlyAtom = store.getAtomValue(for: readableAtom.id)
        store.usedAtoms[Scope.id, default: []].append(.init(scope: Scope.id,
                                                            atom: readableAtom.id,
                                                            watching: false,
                                                            keepAlive: readableAtom.keepAlive))
        usedAtomsSubject.send(.init(scope: Scope.id,
                                    atom: readableAtom.id,
                                    watching: false,
                                    keepAlive: readableAtom.keepAlive))
    }
}
