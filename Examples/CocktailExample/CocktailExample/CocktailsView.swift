import SwiftUI
import Foundation
import Atoms

struct CocktailsView: View {
    @UseAtom(searchCocktailTextAtom) var searchCocktailText
    @UseAtomValue(searchCocktailsAtom) var searchCocktailsState
    @UseAtomValue(favoritesManagerAtom) var favoritesManager
    var body: some View {
        NavigationStack {
            List {
                if let cocktails = searchCocktailsState.value, !cocktails.isEmpty {
                    ForEach(cocktails) { cocktail in
                        NavigationLink {
                            CocktailDetailView(cocktail: cocktail)
                        } label: {
                            CocktailItemView(cocktail: cocktail)
                        }
                    }
                } else {
                    ForEach(favoritesManager.favorites) { cocktail in
                        NavigationLink {
                            CocktailDetailView(cocktail: cocktail)
                        } label: {
                            CocktailItemView(cocktail: cocktail)
                        }
                    }
                }
            }
            .searchable(text: $searchCocktailText)
            .navigationTitle("Search cocktails")
        }
    }
}

struct CocktailsView_Previews: PreviewProvider {
    static var previews: some View {
        CocktailsView()
            .inject(searchCocktailsAtom) {
                .success([.init(idDrink: "1", strDrink: "Drink2", strInstructions: "Some instructions", strImageSource: nil, strDrinkThumb: nil)])
            }
    }
}

