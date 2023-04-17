import Foundation

/// A test store for running isolated operations on a separate `Store` instance.
@MainActor
public struct TestStore {
    
    /// Initializes a new `TestStore` and runs the specified operation on a separate `Store` instance.
    ///
    /// - Parameter operation: An asynchronous closure that takes a `Store` instance and performs the desired operations.
    @discardableResult
    public init(operation: @escaping (Store) async throws -> Void) async rethrows {
        let newStore = Store()
        newStore.onUpdates = StoreConfig.store.onUpdates
        try await StoreConfig.$store.withValue(newStore) {
            try await operation(newStore)
        }
    }
}

