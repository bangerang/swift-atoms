import Foundation
import Combine

struct UsedAtomInfo: Hashable {
    let scope: UUID
    let atom: UUID
    let watching: Bool
    var debounced = 0.0
    var keepAlive: Bool
}

let usedAtomsSubject: PassthroughSubject<UsedAtomInfo, Never> = .init()
