import Foundation
import Combine

/// A generic `AsyncSequenceAtom` represents an asynchronous state for a given value of type `T` while iterating through an `AsyncSequence`.
///
/// `AsyncSequenceAtom` manages the state of an asynchronous sequence producing values of type `T` or throwing an error.
/// The state is represented as an `AsyncState<T>`, which can be `.loading`, `.success(T)`, or `.failure(Error)`.
///
/// Example:
///
/// ```swift
/// let notificationAtom = AsyncSequenceAtom(NotificationCenter.default.notifications(named: UIDevice.orientationDidChangeNotification))
///
/// struct ContentView: View {
///     @UseAtomValue(notificationAtom) var notification
///     var body: some View {
///         if UIDevice.current.orientation.isLandscape {
///             Text("Landscape")
///         } else {
///             Text("Portrait")
///         }
///     }
/// }
/// ```
///
/// - Note: Conforms to the `ReadableAtom` protocol.
public struct AsyncSequenceAtom<T>: ReadableAtom {
    /// The unique identifier for the atom.
    public let id: UUID
    /// The type of the state managed by the atom, which is `AsyncState<T>`.
    public let type = AsyncState<T>.self
    /// A boolean value indicating if the atom should be kept alive.
    public let keepAlive: Bool
    
    private let setup: @MainActor () -> Void
    
    /// Initializes a new instance of `AsyncSequenceAtom` with the specified `AsyncSequence`.
        ///
        /// - Parameters:
        ///   - asyncSequence: An `AsyncSequence` object that produces values of type `T`.
        ///   - keepAlive: A boolean value indicating if the atom should be kept alive. Default is `false`.
        ///   - file: The source file where the `AsyncSequenceAtom` is created. Default is `#file`.
        ///   - function: The function where the `AsyncSequenceAtom` is created. Default is `#function`.
        ///   - line: The line number in the source file where the `AsyncSequenceAtom` is created. Default is `#line`.
    public init<A: AsyncSequence>(_ asyncSequence: A, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) where A.Element == T {
        let id = UUID()
        self.id = id
        self.keepAlive = keepAlive
        let store = StoreConfig.store
        self.setup = {
            let atom = AtomValue<AsyncState<T>>(.loading, id: id, dontCheckEqual: true)
            store.addAtomValue(atom, for: id)
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
            Task { @MainActor in
                store.tasks[id] = Task { @MainActor in
                    do {
                        try await StoreConfig.$store.withValue(store) {
                            for try await value in asyncSequence {
                                guard !Task.isCancelled else {
                                    return
                                }
                                atom.value = .success(value)
                            }
                        }
                    } catch {
                        atom.value = .failure(error)
                    }
                }
            }
        }
        atomConfigurations[id] = setup
    }
    
    /// Initializes a new instance of `AsyncSequenceAtom` with the specified closure that returns an `AsyncSequence`.
        ///
        /// - Parameters:
        ///   - asyncSequence: A closure that returns an `AsyncSequence` object that produces values of type `T`.
        ///   - keepAlive: A boolean value indicating if the atom should be kept alive. Default is `false`.
        ///   - file: The source file where the `AsyncSequenceAtom` is created. Default is `#file`.
        ///   - function: The function where the `AsyncSequenceAtom` is created. Default is `#function`.
        ///   - line: The line number in the source file where the `AsyncSequenceAtom` is created. Default is `#line`.
    public init<A: AsyncSequence>(_ asyncSequence: @escaping () -> A, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) where A.Element == T {
        let id = UUID()
        self.id = id
        self.keepAlive = keepAlive
        self.setup = {
            var cancellable: AnyCancellable?
            let store = StoreConfig.store
            StoreConfig.$store.withValue(store) {
                let atom = create(asyncSequence, id: id) { atom, finishedTask in
                    if finishedTask {
                        cancellable?.cancel()
                    } else {
                        var usedIDs: Set<UUID> = []
                        cancellable = usedAtomsSubject
                            .filter(\.watching)
                            .sink { [weak store] value in
                                guard let store else {
                                    return
                                }
                                StoreConfig.$store.withValue(store) {
                                    if value.scope == id {
                                        if let publisher = store.getSetPublisher(for: value.atom), !usedIDs.contains(value.atom) {
                                            usedIDs.insert(value.atom)
                                            publisher.setterPublisher.handleEvents(receiveOutput: { _ in
                                                atom.value = .loading
                                            }).debounce(for: .seconds(value.debounced), scheduler: DispatchQueue.main).sink {  _ in
                                                
                                                store.tasks[id]?.cancel()
                                                store.tasks[id] = nil
                                                store.tasks[id] = Task { @MainActor in
                                                    do {
                                                        try await StoreConfig.$store.withValue(store) {
                                                            let sequence = asyncSequence()
                                                            for try await value in sequence {
                                                                guard !Task.isCancelled else {
                                                                    return
                                                                }
                                                                guard !atom.overriden else {
                                                                    atom.overriden = false
                                                                    continue
                                                                }
                                                                atom.value = .success(value)
                                                            }
                                                        }
                                                    } catch {
                                                        guard !atom.overriden else {
                                                            atom.overriden = false
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
                    
                }
                store.addAtomValue(atom, for: id)
                setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
            }
        }
        atomConfigurations[id] = setup
    }
}

fileprivate func create<Root, A: AsyncSequence>(_ asyncSequence: @escaping () -> A, id: UUID, taskStatus: @MainActor @escaping ( AtomValue<AsyncState<Root>>, Bool) -> Void) -> AtomValue<AsyncState<Root>> where Root == A.Element {
    let atom = AtomValue<AsyncState<Root>>(.loading, id: id, dontCheckEqual: true)
    let store = StoreConfig.store
    Task { @MainActor in
        atom.getterPublisher.prefix(1).receive(on: DispatchQueue.main).sink { _ in
            if store.tasks[id] == nil {
                Scope.$id.withValue(id, operation: {
                    taskStatus(atom, false)
                    store.tasks[id] = Task { @MainActor in
                        do {
                            taskStatus(atom, false)
                            var didStart = false
                            try await StoreConfig.$store.withValue(store) {
                                let sequence = asyncSequence()
                                for try await value in sequence {
                                    guard !Task.isCancelled else {
                                        return
                                    }
                                    atom.value = .success(value)
                                    if !didStart {
                                        didStart = true
                                        taskStatus(atom, true)
                                    }
                                }
                            }
                        } catch {
                            await MainActor.run {
                                atom.value = .failure(error)
                                taskStatus(atom, true)
                            }
                        }
                    }
                })
                
            }
            
        }.store(in: &store.cancellables[id, default: []])
    }
    
    return atom
}
