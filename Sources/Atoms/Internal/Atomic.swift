import Foundation

final class Atomic<A> {
    private let queue: DispatchQueue
    private var _value: A
    public init(_ value: A, label: String? = nil) {
        let queueLabel = label ?? "Atomic serial queue"
        self.queue = DispatchQueue(label: queueLabel)
        self._value = value
    }

    public var value: A {
        return queue.sync { self._value }
    }

    public func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}
