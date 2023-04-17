import Foundation
import Combine

/// A generic `AsyncAtom` represents an asynchronous state for a given value of type `T`.
///
/// `AsyncAtom` manages an asynchronous operation that produces a value of type `T` or throws an error.
/// The state is represented as an `AsyncState<T>`, which can be `.loading`, `.success(T)`, or `.failure(Error)`.
/// The asynchronous state is automatically updated when the associated operation is performed, and its dependencies change.
///
/// Example:
///
/// ```swift
/// let myAsyncAtom = AsyncAtom {
///     let result = try await someAsyncFunction()
///     return result
/// }
///
/// struct ContentView: View {
///     @UseAtomValue(myAsyncAtom) var asyncState
///     var body: some View {
///         switch asyncState {
///         case .loading:
///             ProgressView()
///         case .success(let value):
///             Text(value)
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
///
/// - Note: Conforms to the `ReadableAtom` protocol.
public struct AsyncAtom<T>: ReadableAtom {
    
    /// The unique identifier for the atom.
    public let type = AsyncState<T>.self
    /// The unique identifier for the atom.
    public let id: UUID
    /// A boolean value indicating if the atom should be kept alive.
    public let keepAlive: Bool
    
    private let operation: @MainActor () async throws -> T
    private let throwOnCancellation: Bool
    private let file: String
    private let function: String
    private let line: Int
    
    /// Initialize a new `AsyncAtom` with the specified parameters.
        ///
        /// - Parameters:
        ///   - keepAlive: A boolean value indicating whether the atom should be kept alive even if no longer used. Default is `false`.
        ///   - throwOnCancellation: A boolean value indicating whether the atom should throw an error if the task is cancelled. Default is `false`.
        ///   - file: The file name where the atom is defined. Default is `#file`.
        ///   - function: The function name where the atom is defined. Default is `#function`.
        ///   - line: The line number where the atom is defined. Default is `#line`.
        ///   - operation: An async closure that performs the operation and returns a value of type `T` or throws an error.
    public init(keepAlive: Bool = false, throwOnCancellation: Bool = false, file: String = #file, function: String = #function, line: Int = #line, operation: @escaping @MainActor () async throws -> T) {
        self.throwOnCancellation = throwOnCancellation
        let id = UUID()
        self.keepAlive = keepAlive
        self.id = id
        self.operation = operation
        self.file = file
        self.function = function
        self.line = line
        atomConfigurations[id] = setup
    }
    
    /// Cancel the current async operation.
    @MainActor
    public func cancel() {
        StoreConfig.store.tasks[id]?.cancel()
    }
    
    /// Reloads the async operation, updating the atom's state.
    @MainActor
    public func reload() {
        runOperation()
    }
    
    @MainActor
    private func setup() {
        var cancellable: AnyCancellable?
        let store = StoreConfig.store
        StoreConfig.$store.withValue(store) {
            let atom = create(operation, id: id, throwOnCancellation: throwOnCancellation) { atom, finishedTask in
                if finishedTask {
                    cancellable?.cancel()
                } else {
                    var usedIDs: Set<UUID> = []
                    cancellable = usedAtomsSubject
                        .filter(\.watching)
                        .filter{ $0.scope == id }
                        .sink { [weak store] value in
                            guard let store else {
                                return
                            }
                            StoreConfig.$store.withValue(store) {
                                if let publisher = store.getSetPublisher(for: value.atom), !usedIDs.contains(value.atom) {
                                    usedIDs.insert(value.atom)
                                    publisher.setterPublisher.handleEvents(receiveOutput: { _ in
                                        atom.value = .loading
                                    }).debounce(for: .seconds(value.debounced), scheduler: DispatchQueue.main).sink {  _ in
                                        store.tasks[id]?.cancel()
                                        store.tasks[id] = nil
                                        store.tasks[id] = Task { @MainActor [cancellable] in
                                            do {
                                                let result = try await StoreConfig.$store.withValue(store) {
                                                    try await operation()
                                                }
                                                cancellable?.cancel()
                                                guard !Task.isCancelled else {
                                                    return
                                                }
                                                atom.value = .success(result)
                                            } catch {
                                                cancellable?.cancel()
                                                if Task.isCancelled && atom.loading && !throwOnCancellation {
                                                    return
                                                }
                                                atom.value = .failure(error)
                                            }
                                        }
                                    }.store(in: &store.cancellables[id, default: []])
                            }
                        }
                    }
                }
            }
            store.addAtomValue(atom, for: id)
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
        }
    }
    
    @MainActor
    private func runOperation() {
        let store = StoreConfig.store
        let atom: AtomValue<AsyncState<T>> = store.getAtomValue(for: id)
        store.tasks[id]?.cancel()
        store.tasks[id] = nil
        
        store.tasks[id] = Task { @MainActor in
            atom.value = .loading
            do {
                let result = try await StoreConfig.$store.withValue(store) {
                    try await operation()
                }
                guard !Task.isCancelled else {
                    return
                }
                atom.value = .success(result)
            } catch {
                if Task.isCancelled && atom.loading && !throwOnCancellation {
                    return
                }
                atom.value = .failure(error)
            }
        }
    }
}

@MainActor
fileprivate func create<Root>(_ callback: @escaping () async throws -> Root, id: UUID, throwOnCancellation: Bool, taskStatus: @MainActor @escaping ( AtomValue<AsyncState<Root>>, Bool) -> Void) -> AtomValue<AsyncState<Root>> {
    let atom = AtomValue<AsyncState<Root>>(.loading, id: id)
    let store = StoreConfig.store
    atom.getterPublisher.prefix(1).receive(on: DispatchQueue.main).sink { _ in
        
        if store.tasks[id] == nil {
            Scope.$id.withValue(id, operation: {
                taskStatus(atom, false)
                store.tasks[id] = Task {
                    do {
                        let result = try await StoreConfig.$store.withValue(store) {
                            try await callback()
                        }
                        guard !atom.overriden else {
                            atom.overriden = false
                            return
                        }
                        
                        await MainActor.run {
                            atom.value = .success(result)
                            taskStatus(atom, true)
                        }
                    } catch {
                        guard !atom.overriden else {
                            atom.overriden = false
                            return
                        }
                        if Task.isCancelled && atom.loading && !throwOnCancellation {
                            return
                        }
                        await MainActor.run {
                            atom.value = .failure(error)
                            taskStatus(atom, true)
                        }
                    }
                }
            })

        }

    }.store(in: &store.cancellables[id, default: []])
    
    return atom
}
