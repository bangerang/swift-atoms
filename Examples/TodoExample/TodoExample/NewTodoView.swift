import SwiftUI
import Atoms

struct NewTodoView: View {
    @UseAtom(todosAtom) var todos
    @State var newTodoName = ""
    var body: some View {
        TextField("Add new todo", text: $newTodoName) {
            if !newTodoName.isEmpty {
                todos.append(.init(name: newTodoName))
                Task { @MainActor in
                    newTodoName = ""
                }

            }
        }
    }
}

struct NewTodoView_Previews: PreviewProvider {
    static var previews: some View {
        NewTodoView()
    }
}
