import Foundation
import Combine
import CustomDump

@dynamicMemberLookup
class AtomValue<Root>: ObservableObject, GetSetPublisher {
    
    var _value: Root
    private var getterSubject = PassthroughSubject<Void, Never>()
    var getterPublisher: AnyPublisher<Void, Never> {
        return getterSubject.eraseToAnyPublisher()
    }
    private var setterSubject = PassthroughSubject<Void, Never>()
    var setterPublisher: AnyPublisher<Void, Never> {
        return setterSubject.eraseToAnyPublisher()
    }
    
    var customGet: (() -> Root)?
    var customSet: ((Root) -> Void)?
    var overriden = false
    
    let id: UUID
    
    var value: Root {
        get {
            getterSubject.send(())
            if let customGet {
                return customGet()
            }
            return _value
        } set {
            let valueToTest = self.customGet?() ?? self._value
            if !areEqual(first: valueToTest, second: newValue) {
                Task { @MainActor in
                    AtomStore.shared.logValue(for: id, value: newValue)
                }
                self.objectWillChange.send()
                if let set = self.customSet {
                    set(newValue)
                } else {
                    self._value = newValue
                }
                self.setterSubject.send(())
            }
        }
    }
    
    init(_ value: Root, id: UUID, dontCheckEqual: Bool = false) {
        self.id = id
        self._value = value
    }
    
    subscript<T>(dynamicMember member: KeyPath<Root, T>) -> T {
        value[keyPath: member]
    }
    
    subscript<T>(dynamicMember member: WritableKeyPath<Root, T>) -> T {
        get {
            value[keyPath: member]
        } set {
            value[keyPath: member] = newValue
        }
    }
}
