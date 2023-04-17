import Foundation

protocol ResettableAtom {
    func reset()
}

extension ResettableAtom where Self: ReadableAtom {
    func onReset(_ value: @escaping (inout Self.T) -> Void) -> Self {
        Task { @MainActor in
            StoreConfig.store.resettableCallbacks[id] = value
        }
        
        return self
    }
}
