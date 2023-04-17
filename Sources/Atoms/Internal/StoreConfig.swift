import Foundation

let defaultStoreID = UUID()
enum StoreConfig {
    @TaskLocal static var store = Store(id: defaultStoreID)
}
