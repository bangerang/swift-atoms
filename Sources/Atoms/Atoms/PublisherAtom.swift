import Foundation
import Combine

/// A generic `PublisherAtom` represents a readable state for a given value of type `T` that comes from a `Publisher`.
///
/// `PublisherAtom` wraps an `AnyPublisher<T, Never>` or `AnyPublisher<T, Error>` and automatically updates the state
/// as new values are received from the publisher. The state is represented as an `AsyncState<T>`, which can be
/// `.loading`, `.success(T)`, or `.failure(Error)`.
///
/// Example:
///
/// ```swift
/// let myPublisher = PassthroughSubject<Int, Never>()
/// let myPublisherAtom = PublisherAtom(myPublisher.eraseToAnyPublisher())
///
/// struct ContentView: View {
///     @UseAtomValue(myPublisherAtom) var asyncState
///
///     var body: some View {
///         VStack {
///             switch asyncState {
///             case .loading:
///                 Text("Loading...")
///             case .success(let value):
///                 Text("Value: \(value)")
///             case .failure(let error):
///                 Text("Error: \(error.localizedDescription)")
///             }
///             Button("Increment") {
///                 myPublisher.send(asyncState.value! + 1)
///             }
///         }
///     }
/// }
/// ```
///
/// - Note: Conforms to the `ReadableAtom` protocol.
public struct PublisherAtom<T>: ReadableAtom {
    /// The type of the value wrapped in the `AsyncState`.
    public let type = AsyncState<T>.self
    /// A unique identifier for the `PublisherAtom`.
    public let id: UUID
    /// A flag indicating if the `PublisherAtom` should be kept alive.
    public let keepAlive: Bool
    
    private let setup: @MainActor () -> Void

    /// Initializes a new instance of `PublisherAtom` with a publisher that never fails.
    ///
    /// - Parameters:
    ///   - publisher: The publisher that provides values of type `T`.
    ///   - keepAlive: A boolean value indicating if the `PublisherAtom` should be kept alive.
    ///   - file: The file where the `PublisherAtom` is created. Defaults to the current file.
    ///   - function: The function where the `PublisherAtom` is created. Defaults to the current function.
    ///   - line: The line where the `PublisherAtom` is created. Defaults to the current line.
    public init(_ publisher: AnyPublisher<T, Never>, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        let store = StoreConfig.store
        self.setup = {
            let atom = AtomValue<AsyncState<T>>(.loading, id: id)
            store.addAtomValue(atom, for: id)
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
            publisher.sink { [weak atom] newValue in
                atom?.value = .success(newValue)
            }.store(in: &store.cancellables[id, default: []])
        }
        atomConfigurations[id] = setup
    }
    
    /// Initializes a new instance of `PublisherAtom` with a publisher that can fail with an error.
    ///
    /// - Parameters:
    ///   - publisher: The publisher that provides values of type `T` and can fail with an error.
    ///   - keepAlive: A boolean value indicating if the `PublisherAtom` should be kept alive.
    ///   - file: The file where the `PublisherAtom` is created. Defaults to the current file.
    ///   - function: The function where the `PublisherAtom` is created. Defaults to the current function.
    ///   - line: The line where the `PublisherAtom` is created. Defaults to the current line.
    public init(publisher: AnyPublisher<T, Error>, keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        let store = StoreConfig.store
        self.setup = {
            let atom = AtomValue<AsyncState<T>>(.loading, id: id)
            store.addAtomValue(atom, for: id)
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
            publisher.sink { [weak atom] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    atom?.value = .failure(error)
                }
            } receiveValue: { [weak atom] newValue in
                atom?.value = .success(newValue)
            }.store(in: &store.cancellables[id, default: []])
        }
        
        Task { @MainActor [setup] in
            atomConfigurations[id] = setup
        }
    }
    
    /// Initializes a new instance of `PublisherAtom` with a closure that returns a publisher that never fails.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean value indicating if the `PublisherAtom` should be kept alive.
    ///   - file: The file where the `PublisherAtom` is created. Defaults to the current file.
    ///   - function: The function where the `PublisherAtom` is created. Defaults to the current function.
    ///   - line: The line where the `PublisherAtom` is created. Defaults to the current line.
    ///   - publisher: A closure that returns a publisher that provides values of type `T`.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, _ publisher: @escaping () -> AnyPublisher<T, Never>) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.setup = {
            var didSetup = false
            let store = StoreConfig.store
            var currentCancellable: AnyCancellable?
            findObservables(using: id) {
                let cancellable = publisher().sink { newValue in
                    if !didSetup {
                        didSetup = true
                        let atom = AtomValue(newValue, id: id)
                        store.addAtomValue(atom, for: id)
                        setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
                    } else {
                        let atom: AtomValue<T> = store.getAtomValue(for: id)
                        atom.value = newValue
                    }
                }
                store.cancellables[id]?.insert(cancellable)
                currentCancellable = cancellable
            } observedChanged: {
                guard let current = currentCancellable else {
                    fatalError()
                }
                store.cancellables[id]?.remove(current)
                let cancellable = publisher().sink { newValue in
                    let atom: AtomValue<T> = store.getAtomValue(for: id)
                    atom.value = newValue
                }
                store.cancellables[id]?.insert(cancellable)
                currentCancellable = cancellable
            }
        }
        
        atomConfigurations[id] = setup
    }
    
    /// Initializes a new instance of `PublisherAtom` with a closure that returns a publisher that can fail with an error.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean value indicating if the `PublisherAtom` should be kept alive.
    ///   - file: The file where the `PublisherAtom` is created. Defaults to the current file.
    ///   - function: The function where the `PublisherAtom` is created. Defaults to the current function.
    ///   - line: The line where the `PublisherAtom` is created. Defaults to the current line.
    ///   - publisher: A closure that returns a publisher that provides values of type `T` and can fail with an error.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, _ publisher: @escaping () -> AnyPublisher<T, Error>) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.setup = {
            var didSetup = false
            let store = StoreConfig.store
            var currentCancellable: AnyCancellable?
            findObservables(using: id) {
                let cancellable = publisher().sink { completion in
                    let atom: AtomValue<AsyncState<T>> = store.getAtomValue(for: id)
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        atom.value = .failure(error)
                    }
                } receiveValue: { newValue in
                    if !didSetup {
                        didSetup = true
                        let atom = AtomValue(newValue, id: id)
                        store.addAtomValue(atom, for: id)
                        setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
                    } else {
                        let atom: AtomValue<T> = store.getAtomValue(for: id)
                        atom.value = newValue
                    }
                }
                store.cancellables[id]?.insert(cancellable)
                currentCancellable = cancellable
            } observedChanged: {
                guard let current = currentCancellable else {
                    fatalError()
                }
                store.cancellables[id]?.remove(current)
                let cancellable = publisher().sink { completion in
                    let atom: AtomValue<AsyncState<T>> = store.getAtomValue(for: id)
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        atom.value = .failure(error)
                    }
                } receiveValue: { newValue in
                    let atom: AtomValue<T> = store.getAtomValue(for: id)
                    atom.value = newValue
                }
                
                guard let current = currentCancellable else {
                    fatalError()
                }
                store.cancellables[id]?.remove(current)

                store.cancellables[id]?.insert(cancellable)
                currentCancellable = cancellable
            }
        }
        
        atomConfigurations[id] = setup
    }
}
