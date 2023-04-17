import Foundation
import Combine

protocol GetSetPublisher {
    var getterPublisher: AnyPublisher<Void, Never> { get }
    var setterPublisher: AnyPublisher<Void, Never> { get }
}
