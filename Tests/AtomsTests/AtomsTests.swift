import XCTest
@testable import Atoms
import Combine

final class swift_atomsTests: XCTestCase {
    @MainActor
    func testDerivedAtom() async throws {
        let atom = Atom("Bar")
        let derived = DerivedAtom<String> {
            let useAtom = UseAtom(atom)
            return useAtom.wrappedValue.uppercased()
        }
        @CaptureAtom(atom) var value: String
        @CaptureAtomValue(derived) var derivedValue: String
        value = "foo"
        try await expectEqual(derivedValue, "FOO")
    }
    
    @MainActor
    func testKeepAliveFalse() async throws {
        let atom = Atom("Foo", keepAlive: false)
        var useAtomValue: UseAtomValue<String>? = nil
        useAtomValue = withExtendedLifetime(useAtomValue, {
            UseAtomValue(atom)
        })
        useAtomValue = nil
        let watchCount = StoreConfig.store.viewRefs.value[atom.id]
        try await expectEqual(watchCount, 0)
        try await expect {
            let configured = StoreConfig.store.configuredAtoms
            return !configured.contains(atom.id)
        }
    }
    
    @MainActor
    func testKeepAlive() async throws {
        try await TestStore { store in
            let atom = Atom("Foo", keepAlive: true)
            var useAtomValue: UseAtomValue<String>? = nil
            useAtomValue = withExtendedLifetime(useAtomValue, {
                UseAtomValue(atom)
            })
            useAtomValue = nil
            try await expect {
                let configured = StoreConfig.store.configuredAtoms
                return configured.contains(atom.id)
            }
        }
    }
    
    @MainActor
    func testOnUpdate() async throws {
        try await TestStore { store in
            var didSet = false
            let atom = Atom("Foo")
                .onUpdate(skip: 1) { newValue in
                    if newValue == "Bar" {
                        didSet = true
                    }
                }
            @CaptureAtom(atom) var value: String
            value = "Bar"
            try await expect(didSet)
        }
    }
    
    @MainActor
    func testReset() async throws {
        try await TestStore { store in
            var calledOnReset = false
            let atom = WillSetAtom("First") { newValue in
                newValue.uppercased()
            }.onReset { _ in
                calledOnReset = true
            }
            @CaptureAtom(atom) var value: String
            value = "Second"
            try await expectEqual(value, "SECOND")
            atom.reset()
            try await expectEqual(value, "First")
            try await expect(calledOnReset)
        }
    }
    
    @MainActor
    func testGetSetAtom() async throws {
        try await TestStore { _ in
            var cached = 0
            let other = Atom(0)
            let other2 = Atom(0)
            let atom = GetSetAtom {
                let useAtomValue = UseAtomValue(other2)
                return cached + useAtomValue.wrappedValue
            } set: { newValue in
                let useAtomValue = UseAtomValue(other)
                cached = useAtomValue.wrappedValue + newValue * 2
            }
            @CaptureAtom(atom) var getSet: Int
            @CaptureAtom(other) var otherValue: Int
            @CaptureAtom(other2) var otherValue2: Int
            getSet = 1
            try await expectEqual(getSet, 2)
            otherValue = 1
            try await expectEqual(getSet, 3)
            otherValue2 = 1
            try await expectEqual(getSet, 4)
        }
    }
    
    @MainActor
    func testAsyncAtom() async throws {
        try await TestStore { _ in
            let dependencyAtom = Atom(0)
            let asyncFunc: () async throws -> Int = {
                return 1
            }
            let asyncAtom = AsyncAtom {
                let dependency = UseAtomValue(dependencyAtom).wrappedValue
                let value = try await asyncFunc()
                return value + dependency
            }
            @CaptureAtomValue(asyncAtom) var asyncValue
            try await expectEqual(asyncValue.loading, true)
            try await expectEqual(asyncValue.value, 1)
            @CaptureAtom(dependencyAtom) var dependency: Int
            dependency = 1
            try await expectEqual(asyncValue.value, 2)
        }
    }
    
    @MainActor
    func testAsyncAtomFail() async throws {
        try await TestStore { _ in
            let dependencyAtom = Atom(0)
            enum MyErr: Error {
                case first
            }
            let asyncFunc: () async throws -> Int = {
                let dependency = UseAtomValue(dependencyAtom).wrappedValue
                if dependency == 0 {
                    throw MyErr.first
                } else {
                    return 1
                }
            }
            let asyncAtom = AsyncAtom {
                let dependency = UseAtomValue(dependencyAtom).wrappedValue
                let value = try await asyncFunc()
                return value + dependency
            }
            @CaptureAtomValue(asyncAtom) var asyncValue
            try await expectEqual(asyncValue.loading, true)
            try await expect {
                if let error = asyncValue.failure as? MyErr {
                    return error == MyErr.first
                }
                return false
            }
            @CaptureAtom(dependencyAtom) var dependency: Int
            dependency = 1
            try await expectEqual(asyncValue.value, 2)
        }
    }
    
    @MainActor
    func testAsyncAtomReload() async throws {
        try await TestStore { _ in
            let asyncFunc: () async throws -> Int = {
                return 1
            }
            let asyncAtom = AsyncAtom {
                return try await asyncFunc()
            }
            @CaptureAtomValue(asyncAtom) var asyncValue
            try await expectEqual(asyncValue.loading, true)
            try await expectEqual(asyncValue.value, 1)
            asyncAtom.reload()
            try await expectEqual(asyncValue.loading, true)
            try await expectEqual(asyncValue.value, 1)
        }
    }
    
    @available(iOS 16.0, *)
    @available(macOS 13.0, *)
    @MainActor
    func testAsyncSequenceAtom() async throws {
        try await TestStore { _ in
            let numbers = PassthroughSubject<Int, Never>()
            let asyncSeqAtom = AsyncSequenceAtom(numbers.values)
            let input = [0, 1, 2]
            @CaptureAtomValue(asyncSeqAtom) var asyncSeq: AsyncState<Int>
            Task {
                for number in input {
                    try await Task.sleep(until: .now + .seconds(0.01), clock: .continuous)
                    numbers.send(number)
                }
            }
            var expected = Set([Int]())
            try await expect {
                if let value = asyncSeq.value {
                    expected.insert(value)
                }
                return expected == Set(input)
            }
        }
    }
    
    @MainActor
    func testPublisherAtom() async throws {
        try await TestStore { _ in
            class SomeObj: ObservableObject {
                @Published var number = 0
            }
            let obj = SomeObj()
            let publisherAtom = PublisherAtom(obj.$number.eraseToAnyPublisher())
            @CaptureAtomValue(publisherAtom) var publisher
            try await expectEqual(publisher.value, 0)
            obj.number = 1
            try await expectEqual(publisher.value, 1)
        }
    }
    
    @MainActor
    func testObservableObjectAtom() async throws {
        try await TestStore { _ in
            class SomeObj: ObservableObject {
                @Published var number = 0
            }
            let obj = SomeObj()
            let observableObjAtom = ObservableObjectAtom(obj)
            @CaptureAtomValue(observableObjAtom) var observableObj
            try await expectEqual(observableObj.number, 0)
            obj.number = 1
            try await expectEqual(observableObj.number, 1)
        }
    }
}
