import Foundation

struct Todo: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var completed = false
}

extension Array where Element == Todo {
    static var mock: [Todo] {
        [
            .init(name: "Todo1"),
            .init(name: "Todo2"),
            .init(name: "Todo3"),
            .init(name: "Todo4", completed: true)
        ]
    }
}

enum FilterOption: String, CaseIterable {
    case all = "Show all"
    case notCompleted = "Not completed"
    case completed = "Completed"
}
