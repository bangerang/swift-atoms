import Foundation
import SwiftUI
import Combine

/// A property wrapper that provides an `AnyPublisher<T, Never>` that emits the current value of the atom and any subsequent updates.
///
/// Usage:
///
/// ```swift
/// class ViewController: UIViewController {
///     @CaptureAtomPublisher(searchTextAtom) var textPublisher
///
///     private let label = UILabel()
///     private var cancellable: AnyCancellable?
///
///     override func viewDidLoad() {
///         super.viewDidLoad()
///         view.addSubview(label)
///         cancellable = textPublisher
///             .sink { [weak self] text in
///                 self?.label.text = text
///             }
///     }
/// }
/// ```
///

@propertyWrapper
public struct CaptureAtomPublisher<T> {
    /// The wrapped `ReadableAtom` value as an `AnyPublisher`.
    public var wrappedValue: AnyPublisher<T, Never> {
        let setterPublisher = atom.setterPublisher.map { atom.value }
        return Publishers.MergeMany(
            Just(atom.value).eraseToAnyPublisher(),
            setterPublisher.eraseToAnyPublisher()
        ).eraseToAnyPublisher()
    }
    
    @ObservedObject private var atom: AtomValue<T>
    private var refCounter: RefCounter? = nil
    
    /// Initializes a new `CaptureAtomPublisher` instance for the given `ReadableAtom`.
    ///
    /// - Parameter readableAtom: A `ReadableAtom` instance whose value will be captured by the `CaptureAtomPublisher`.
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
        let atom: AtomValue<T> = store.getAtomValue(for: readableAtom.id)
        _atom = .init(wrappedValue: atom)
        store.usedAtoms[Scope.id, default: []].append(.init(scope: Scope.id,
                                                            atom: readableAtom.id,
                                                            watching: true,
                                                            debounced: 0,
                                                            keepAlive: readableAtom.keepAlive))
        usedAtomsSubject.send(.init(scope: Scope.id,
                                    atom: readableAtom.id,
                                    watching: true,
                                    debounced: 0,
                                    keepAlive: readableAtom.keepAlive))
    }
    
    init<R: ReadableAtom>(onUpdate readableAtom: R) where R.T == T {
        readableAtom.runSetupIfNeeded()
        let store = StoreConfig.store
        let atom: AtomValue<T> = store.getAtomValue(for: readableAtom.id)
        _atom = .init(wrappedValue: atom)
    }
}
