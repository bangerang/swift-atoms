import Foundation

/// A generic `GetSetAtom` represents a readable and writable state for a given value of type `T`.
///
/// `GetSetAtom` manages a custom getter and setter for the value of type `T`.
/// The state is updated automatically when any of its dependencies change.
///
/// Example:
///
/// ```swift
/// let seenOnboardingAtom = GetSetAtom(get: {
///     return UserDefaults.standard.bool(forKey: "seenOnboarding")
/// }, set: { newValue in
///     UserDefaults.standard.set(newValue, forKey: "seenOnboarding")
/// })
///
/// struct ContentView: View {
///     @UseAtom(seenOnboardingAtom) var seenOnboarding
///
///     var body: some View {
///         VStack {
///             if !seenOnboarding {
///                 OnboardingView()
///                 Button("Finish Onboarding") {
///                     seenOnboarding = true
///                 }
///             } else {
///                 MainAppView()
///             }
///         }
///     }
/// }
/// ```
///
/// - Note: Conforms to the `WritableAtom` and `ResettableAtom` protocols.
public struct GetSetAtom<T>: WritableAtom, ResettableAtom {
    /// The type of the value managed by this `GetSetAtom`.
    public let type = T.self
    /// A unique identifier for this `GetSetAtom`.
    public let id: UUID
    /// A boolean flag indicating whether the `GetSetAtom` should be kept alive.
    public let keepAlive: Bool
    
    private class Cache {
        var value: T?
        weak var atom: AtomValue<T>?
    }
    private let cache = Cache()
    private let get: @MainActor () -> T
    private let setup: @MainActor () -> Void
  
    /// Initializes a new `GetSetAtom` with custom getter and setter functions for the value of type `T`.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean flag indicating whether the `GetSetAtom` should be kept alive. Defaults to `false`.
    ///   - file: The name of the file where this `GetSetAtom` is created. Defaults to `#file`.
    ///   - function: The name of the function where this `GetSetAtom` is created. Defaults to `#function`.
    ///   - line: The line number in the file where this `GetSetAtom` is created. Defaults to `#line`.
    ///   - get: The custom getter function that retrieves the current value of type `T`.
    ///   - set: The custom setter function that sets the new value of type `T`.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, get: @MainActor @escaping () -> T, set: @MainActor @escaping (T) -> Void) {
        self.keepAlive = keepAlive
        let id = UUID()
        self.id = id
        self.get = get
        self.setup = { [cache] in
            var didSetupGet = false
            let store = StoreConfig.store
            cache.value = get()
            let getProxy: () -> T = {
                if !didSetupGet {
                    didSetupGet = true
                    return StoreConfig.$store.withValue(store) {
                        let value = findObservables(using: id) {
                            return get()
                        } observedChanged: { _ in
                            let value = get()
                            cache.atom?.objectWillChange.send()
                            cache.value = value
                        }
                        return value
                    }     
                } else {
                    guard let value = cache.value else {
                        fatalError()
                    }
                    return value
                }
            }
            
            var didSetupSet = false
            let setProxy: (T) -> Void = { newValue in
                if !didSetupSet {
                    didSetupSet = true
                    StoreConfig.$store.withValue(store) {
                        findObservables(using: id) {
                            set(newValue)
                        } observedChanged: {
                            set(newValue)
                            cache.value = get()
                        }
                    }

                } else {
                    set(newValue)
                }
                cache.value = get()
            }
            
            let atom = AtomValue<T>(getProxy(), id: id)
            atom.customGet = getProxy
            atom.customSet = setProxy
            store.addAtomValue(atom, for: id)
            cache.atom = atom
            setDebugInfoForCurrentStorage(id: id, file: file, function: function, line: line)
        }
        atomConfigurations[id] = setup
    }
    
    /// Resets the value of the `GetSetAtom` to the initial state as defined by the custom getter.
    public func reset() {
        Task { @MainActor in
            cache.value = get()
        }
        
    }
}
