import Foundation
import Combine

/// `Store` manages the state of all atoms and their dependencies.
///
/// It stores the state for atoms, tracks dependencies between them, and updates the state when required.
/// The `Store` class is the core of the state management system.
public final class Store {
    @MainActor
    var cancellables: [UUID: Set<AnyCancellable>] = [:]
    @MainActor
    var tasks: [UUID : Task<Void, Error>] = [:]
    @MainActor
    var overrides: [UUID: Any] = [:]
    @MainActor
    var atomDependencies: [UUID: Set<UUID>] = [:]
    @MainActor
    var resettables: [UUID: ResettableAtom] = [:]
    @MainActor
    var debugInfo: [UUID: DebugInfo] = [:]
    @MainActor
    var configuredAtoms: Set<UUID> = []
    @MainActor
    var resettableCallbacks: [UUID: Any] = [:]
    @MainActor
    var usedAtoms: [UUID: [UsedAtomInfo]] = [:]
    @MainActor
    var didSetupUpdates = false
    var onUpdates = [UUID: @MainActor () -> Void]()
    @MainActor
    var customDebugLabels: [UUID: String] = [:]
    
    var watchCount = Atomic([UUID: Int]())
    var viewRefs = Atomic([UUID: Int]())
    
    var isTestStore: Bool {
        return id != defaultStoreID
    }
    
    private let id: UUID
    private var atomMap: [UUID: Any] = [:]
    
    init(id: UUID = UUID()) {
        self.id = id
        Task { @MainActor in
            usedAtomsSubject.filter {
                !$0.keepAlive
            }.sink { [weak self] info in
                self?.atomDependencies[info.scope, default: []].insert(info.atom)
            }.store(in: &cancellables[id, default: []])
        }
    }
    
    /// Injects a custom value for a specific `ReadableAtom`.
    ///
    /// This method is useful for testing or mocking purposes. It allows you to provide a custom value for an atom,
    /// overriding its actual state.
    ///
    /// - Parameters:
    ///   - primitive: The `ReadableAtom` you want to inject a custom value for.
    ///   - mutation: A closure that returns the custom value for the specified atom.
    @MainActor
    public func inject<R: ReadableAtom>(_ primitive: R, mutation: @escaping () -> R.T) {
        overrides[primitive.id] = mutation
        if let atom: AtomValue<R.T> = getAtomValue(for: primitive.id) {
            atom.value = mutation()
        }
    }
    
    @MainActor
    func getAtomValue<T>(for id: UUID) -> AtomValue<T> {
        guard let atom = atomMap[id] as? AtomValue<T> else {
            fatalError()
        }
        return atom
    }
    
    @MainActor
    func getAtomValue<T>(for id: UUID) -> AtomValue<T>? {
        atomMap[id] as? AtomValue<T>
    }
    
    @MainActor
    func addAtomValue<T>(_ atom: AtomValue<T>, for id: UUID) {
        atomMap[id] = atom
    }
    
    @MainActor
    func getSetPublisher(for id: UUID) -> GetSetPublisher? {
        atomMap[id] as? GetSetPublisher
    }
    
    @MainActor
    func removeAtomValue(for id: UUID) {
        atomMap[id] = nil
    }
    
}

var atomConfigurations: [UUID: @MainActor () -> Void] = [:]
