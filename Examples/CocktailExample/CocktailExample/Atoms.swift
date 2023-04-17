import Foundation
import Atoms

let cocktailServiceAtom = Atom(CocktailService(search: CocktailAPI.searchCocktail))

let searchCocktailTextAtom = Atom("")

let searchCocktailsAtom = AsyncAtom<[Cocktail]> {
    @UseAtomValue(searchCocktailTextAtom) var searchText
    @UseAtomValue(cocktailServiceAtom) var service
    if searchText.isEmpty {
        return []
    }
    return try await service.search(searchText)
}

let favoritesAtom = Atom<[Cocktail]>([])

let favoritesManagerAtom = ObservableObjectAtom(FavoritesManager())


