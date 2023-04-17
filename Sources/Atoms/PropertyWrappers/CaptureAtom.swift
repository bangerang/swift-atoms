import Foundation
import SwiftUI

/// A property wrapper that captures the atom's value and provides read and write access without being reactive to changes.
///
/// Usage:
///
/// ```swift
/// @MainActor
/// func testSignup() async throws {
///     try await TestStore { store in
///         @CaptureAtom(usernameAtom) var username: String
///         @CaptureAtom(passwordAtom) var password: String
///         @CaptureAtomValue(signupIsValidAtom) var signupIsValid: Bool
///         XCTAssert(!signupIsValid)
///         username = "johndoe"
///         password = "passw0rD"
///         try await expect(signupIsValid)
///     }
/// }
/// ```
///


@propertyWrapper @MainActor
public struct CaptureAtom<T> {
    /// The current value of the wrapped `ReadableAtom`.
    public var wrappedValue: T {
        get {
            return atom.value
        } nonmutating set {
            atom.value = newValue
        }
    }
    
    private let atom: AtomValue<T>
    private var refCounter: RefCounter? = nil
    
    /// Initializes a new `CaptureAtom` instance for the given `WritableAtom`.
    ///
    /// - Parameter writableAtom: A `WritableAtom` instance whose value will be captured by the `CaptureAtom`.
    ///
    public init<W: WritableAtom>(_ writableAtom: W) where W.T == T {
        writableAtom.runSetupIfNeeded()
        let store = StoreConfig.store
        if !writableAtom.keepAlive {
            if Scope.id == defaultScopeID {
                refCounter = RefCounter(id: writableAtom.id)
            } else {
                store.watchCount.mutate { value in
                    value[writableAtom.id, default: 0] += 1
                }
            }
        }
        atom = store.getAtomValue(for: writableAtom.id)
        store.usedAtoms[Scope.id, default: []].append(.init(scope: Scope.id,
                                                            atom: writableAtom.id,
                                                            watching: false,
                                                            keepAlive: writableAtom.keepAlive))
        usedAtomsSubject.send(.init(scope: Scope.id,
                                    atom: writableAtom.id,
                                    watching: false,
                                    keepAlive: writableAtom.keepAlive))
    }
}
