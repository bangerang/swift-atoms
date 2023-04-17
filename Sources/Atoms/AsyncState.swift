/// An enum representing the state of an asynchronous operation.
public enum AsyncState<Root>: Equatable {
    
    public static func == (lhs: AsyncState, rhs: AsyncState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.success(let lhs), .success(let rhs)):
            return areEqual(first: lhs, second: rhs)
        default:
            return false
        }
    }
    
    /// Indicates that the asynchronous operation is in progress.
    case loading
    
    /// Indicates that the asynchronous operation has completed successfully with the provided `Root` value.
    case success(Root)
    
    /// Indicates that the asynchronous operation has failed with the provided `Error`.
    case failure(Error)
    
    /// The `Root` value associated with the `.success` case, if any.
    public var value: Root? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    /// Returns `true` if the `AsyncState` is in the `.loading` case, `false` otherwise.
    public var loading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// The `Error` value associated with the `.failure` case, if any.
    public var failure: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
