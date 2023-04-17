import Foundation
import Combine

/// A protocol that represents a readable Atom with a value of a certain type `T`.
public protocol ReadableAtom {
    associatedtype T
    /// A unique identifier for the Atom.
    var id: UUID { get }
    /// The type of the Atom's value.
    var type: T.Type { get }
    /// A Boolean value indicating whether the Atom should be kept alive.
    var keepAlive: Bool { get }
}

extension ReadableAtom {
    @MainActor
    func runSetupIfNeeded() {
        if shouldRunSetup() {
            let store = StoreConfig.store
            
            store.configuredAtoms.insert(id)
            guard let setup = atomConfigurations[id] else {
                fatalError()
            }
            
            setup()
            
            if let overriden = store.overrides[id] {
                guard let function = overriden as? () -> T else {
                    fatalError()
                }
                let atom: AtomValue<T> = store.getAtomValue(for: id)
                atom.value = function()
                atom.overriden = true
            }
            if let resettable = self as? ResettableAtom {
                store.resettables[id] = resettable
            }
            
            if let update = StoreConfig.store.onUpdates[id] {
                update()
            }
        }
    }
    
    @MainActor
    private func shouldRunSetup() -> Bool {
        let store = StoreConfig.store
        return !store.configuredAtoms.contains(id)
    }
    
    public func debugLabel(_ label: String) -> Self {
        Task { @MainActor in
            let store = StoreConfig.store
            store.customDebugLabels[id] = label
        }
        return self
    }
    
}

extension ReadableAtom {
    /// Registers a callback to be called when the Atom's value updates.
    ///
    /// - Parameters:
    ///   - skip: The number of initial values to skip before invoking the callback. Defaults to `0`.
    ///   - callback: A closure that is called with the new value when the Atom's value updates.
    ///
    /// - Returns: The modified `ReadableAtom` with the `onUpdate` callback registered.
    @discardableResult
    public func onUpdate(skip: Int = 0, _ callback: @MainActor @escaping (T) -> Void) -> Self {
        let onUpdate: @MainActor () -> Void = {
            @CaptureAtomPublisher(onUpdate: self) var publisher: AnyPublisher<T, Never>
            let store = StoreConfig.store
            publisher.dropFirst(skip).sink { [weak store] newValue in
                guard let store else {
                    return
                }
                StoreConfig.$store.withValue(store) {
                    callback(newValue)
                }
            }.store(in: &StoreConfig.store.cancellables[id, default: []])
        }
        StoreConfig.store.onUpdates[id] = onUpdate
        return self
    }
}
