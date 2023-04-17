//
//  CocktaiItemView.swift
//  CocktailExample
//
//  Created by Johan Thorell on 2023-04-17.
//

import Foundation
import SwiftUI
import Atoms

struct CocktailItemView: View {
    @UseAtomValue(favoritesManagerAtom) var favoritesManager
    let cocktail: Cocktail
    
    var body: some View {
        HStack {
            CocktailImageView(imageSource: cocktail.strDrinkThumb, size: .thumbnail)
            Text(cocktail.strDrink)
            Spacer()
            if favoritesManager.isFavorite(cocktail) {
                Image(systemName: "star.fill")
            }
        }.swipeActions {
            if favoritesManager.isFavorite(cocktail) {
                Button("Remove favorite") {
                    favoritesManager.remove(cocktail)
                }.tint(.red)
            } else {
                Button("Add to favorite") {
                    favoritesManager.add(cocktail)
                }.tint(.indigo)
            }
        }
    }
}

struct CocktailItemView_Previews: PreviewProvider {
    static var previews: some View {
        CocktailItemView(cocktail: .mock)
            .inject(favoritesManagerAtom) {
                .init(favorites: [.mock])
            }
    }
}
