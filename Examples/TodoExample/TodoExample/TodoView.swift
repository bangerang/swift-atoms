import SwiftUI
import Atoms

struct TodoView: View {
    @UseAtomValue(filteredTodosAtom) var filteredTodos
    @UseAtom(filterTodosOptionAtom) var filterTodosOption
    @UseAtom(searchTodosAtom) var searchText
    @UseAtom(todosAtom) var todos
    
    var body: some View {
        NavigationStack {
            List {
                NewTodoView()
                ForEach(filteredTodos) { todo in
                    TodoItemView(todoAtom: Atom(todo).onUpdate(skip: 1) { newValue in
                        if let index = todos.firstIndex(of: todo) {
                            todos[index] = newValue
                        }
                    })
                }.onDelete { indexSet in
                    todos.remove(atOffsets: indexSet)
                }
            }
            .animation(.easeInOut, value: filteredTodos)
            .searchable(text: $searchText)
            .toolbar {
                Picker("", selection: $filterTodosOption) {
                    ForEach(FilterOption.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
            }
            .navigationTitle("Todos")
        }
    }
}

struct TodoView_Previews: PreviewProvider {
    static var previews: some View {
        TodoView()
            .inject(todosAtom) {
                .mock
            }
    }
}
