//
//  PublisherValueAtom.swift
//  SwiftAtomProj
//
//  Created by Johan Thorell on 2023-03-16.
//

import Foundation
import SwiftUI
import Combine

/// A generic `PublishedAtom` represents a readable state for a given value of type `T` that comes from a `Published` property wrapper.
///
/// `PublishedAtom` wraps the `Published<T>.Publisher` of a `Published` property, and the state is updated automatically when the `Published` property changes.
///
/// Example:
///
/// ```swift
///     class MyModel: ObservableObject {
///         @Published var myValue: Int = 0
///     }
///
///     let model = MyModel()
///     let myPublishedAtom = PublishedAtom(model.$myValue)
///
///     struct ContentView: View {
///         @UseAtomValue(myPublishedAtom) var myValue
///
///         var body: some View {
///             VStack {
///                 Text("Value: \(myValue)")
///                 Button("Increment") {
///                     model.myValue += 1
///                 }
///             }
///         }
///     }
/// ```
///
/// - Note: Conforms to the `ReadableAtom` protocol.
public struct PublishedAtom<T>: ReadableAtom {
    /// The type of the value managed by this `PublishedAtom`.
    public let type: T.Type
    /// A unique identifier for this `PublishedAtom`.
    public let id: UUID
    /// A boolean flag indicating whether the `PublishedAtom` should be kept alive.
    public let keepAlive: Bool
    
    private let setup: @MainActor () -> Void
    
    /// Initializes a new `PublishedAtom` with a `Published<T>.Publisher`.
    ///
    /// - Parameters:
    ///   - published: A `Published<T>.Publisher` to be wrapped by the `PublishedAtom`.
    ///   - keepAlive: A boolean flag indicating whether the `PublishedAtom` should be kept alive. Defaults to `false`.
    public init(_ published: Published<T>.Publisher, keepAlive: Bool = false) {
        self.keepAlive = keepAlive
        self.type = T.self
        let id = UUID()
        self.id = id
        var didSetup = false
        self.setup = {
            let store = StoreConfig.store
            published.sink { newValue in
                if !didSetup {
                    didSetup = true
                    let atom = AtomValue(newValue, id: id)
                    store.addAtomValue(atom, for: id)
                } else {
                    let atom: AtomValue<T> = store.getAtomValue(for: id)
                    atom.value = newValue
                }
            }.store(in: &store.cancellables[id, default: []])
        }
        atomConfigurations[id] = setup
    }
    
    /// Initializes a new `PublishedAtom` with a closure returning a `Published<T>.Publisher`.
    ///
    /// - Parameters:
    ///   - keepAlive: A boolean flag indicating whether the `PublishedAtom` should be kept alive. Defaults to `false`.
    ///   - file: The name of the file where this `PublishedAtom` is created. Defaults to `#file`.
    ///   - function: The name of the function where this `PublishedAtom` is created. Defaults to `#function`.
    ///   - line: The line number in the file where this `PublishedAtom` is created. Defaults to `#line`.
    ///   - published: A closure that returns a `Published<T>.Publisher` to be wrapped by the `PublishedAtom`.
    public init(keepAlive: Bool = false, file: String = #file, function: String = #function, line: Int = #line, _ published: @escaping @MainActor () -> Published<T>.Publisher) {
        self.keepAlive = keepAlive
        self.type = T.self
        let id = UUID()
        self.id = id
        self.setup = {
            var didSetup = false
            let store = StoreConfig.store
            var currentCancellable: AnyCancellable?
            findObservables(using: id) {
                let cancellable = published().sink { newValue in
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
                store.cancellables[id, default: []].insert(cancellable)
                currentCancellable = cancellable
            } observedChanged: {
                guard let current = currentCancellable else {
                    fatalError()
                }
                store.cancellables[id]?.remove(current)
                let cancellable = published().sink { newValue in
                    let atom: AtomValue<T> = store.getAtomValue(for: id)
                    atom.value = newValue
                }
                store.cancellables[id]?.insert(cancellable)
                currentCancellable = cancellable
            }
        }
        
        atomConfigurations[id] = setup
    }
}
