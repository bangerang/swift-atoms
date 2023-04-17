import SwiftUI
import Atoms

struct TodoItemView: View {
    @UseAtom var todo: Todo
    
    init(todoAtom: Atom<Todo>) {
        self._todo = UseAtom(todoAtom)
    }
    var body: some View {
        HStack {
            TextField("", text: $todo.name)
                .strikethrough(todo.completed)
            Toggle("", isOn: $todo.completed)
            
        }
    }
}

struct TodoItemView_Previews: PreviewProvider {
    static var previews: some View {
        TodoItemView(todoAtom: .init(.init(name: "Todo")))
    }
}
