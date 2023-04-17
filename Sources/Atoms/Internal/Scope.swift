import Foundation

let defaultScopeID = UUID()
enum Scope {
    @TaskLocal static var id = defaultScopeID
}
