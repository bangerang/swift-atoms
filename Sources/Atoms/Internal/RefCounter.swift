import Foundation
import Combine

let refCounterDecreased = PassthroughSubject<UUID, Never>()

class RefCounter {
    internal init(id: UUID) {
        self.id = id
        let store = StoreConfig.store
        store.viewRefs.mutate { value in
            value[id, default: 0] += 1
        }
    }
    
    let id: UUID
    
    deinit {
        let store = StoreConfig.store
        store.viewRefs.mutate { value in
            value[id, default: 0] -= 1
        }
        
        
        DispatchQueue.main.async { [id] in
            if let viewsRefs = store.viewRefs.value[id], viewsRefs <= 0 {
                if store.watchCount.value[id, default: 0] == 0 {
                    store.removeAtomValue(for: id)
                    store.cancellables[id]?.removeAll()
                    store.configuredAtoms.remove(id)
                } else {
                    refCounterDecreased.send(id)
                }
                
                if let depencies = store.atomDependencies[id] {
                    for depency in depencies {
                        store.watchCount.mutate { value in
                            value[depency]? -= 1
                        }
                        
                        if store.watchCount.value[depency, default: 0] == 0, let dependencyViewRefs = store.viewRefs.value[depency], dependencyViewRefs <= 0 {
                            store.removeAtomValue(for: id)
                            store.configuredAtoms.remove(depency)
                            store.cancellables[depency]?.removeAll()
                        } else {
                            refCounterDecreased.send(depency)
                        }
                    }
                }
            }
        }

    }
}
