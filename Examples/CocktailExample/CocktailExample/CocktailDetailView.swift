import Foundation
import SwiftUI
import Atoms

struct CocktailDetailView: View {
    let cocktail: Cocktail
    @UseAtomValue(favoritesManagerAtom) var favoritesManager
    
    var body: some View {
        ScrollView {
            CocktailImageView(imageSource: cocktail.strImageSource, size: .regular)
            Text(cocktail.strInstructions)
        }
        .padding()
        .navigationTitle(cocktail.strDrink)
        .toolbar {
            if favoritesManager.isFavorite(cocktail) {
                Button {
                    favoritesManager.remove(cocktail)
                } label: {
                    Image(systemName: "star.fill")
                }
            } else {
                Button {
                    favoritesManager.add(cocktail)
                } label: {
                    Image(systemName: "star")
                }
            }
        }
    }
}

struct CocktailDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CocktailDetailView(cocktail: .mock)
                .inject(favoritesManagerAtom) {
                    .init(favorites: [.mock])
                }
        }
    }
}
