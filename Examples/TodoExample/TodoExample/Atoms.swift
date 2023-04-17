import Atoms

let todosAtom = Atom<[Todo]>([])

let filterTodosOptionAtom = Atom(FilterOption.all)

let searchTodosAtom = Atom("")

let filteredTodosAtom = DerivedAtom {
    @UseAtomValue(searchTodosAtom) var searchText
    @UseAtomValue(todosAtom) var todos
    @UseAtomValue(filterTodosOptionAtom) var filterTodosOption;
    
    let searched = searchText.isEmpty ? todos : todos.filter {
        return $0.name.localizedCaseInsensitiveContains(searchText)
    }
    
    switch filterTodosOption {
    case .all:
        return searched
    case .notCompleted:
        return searched.filter { !$0.completed }
    case .completed:
        return searched.filter { $0.completed }
    }
}

