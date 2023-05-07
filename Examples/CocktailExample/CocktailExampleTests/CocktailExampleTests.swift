//
//  CocktailExampleTests.swift
//  CocktailExampleTests
//
//  Created by Johan Thorell on 2023-04-17.
//

import XCTest
@testable import CocktailExample
import Atoms

final class CocktailExampleTests: XCTestCase {

    @MainActor
    func testSearchForCocktail() async throws {
        let mock: [Cocktail] = [.mock]
        try await TestStore { store in
            store.inject(cocktailServiceAtom) {
                .init { _ in
                    return mock
                }
            }
            @CaptureAtomValue(searchCocktailsAtom) var cocktailState: AsyncState<[Cocktail]>
            @CaptureAtom(searchCocktailTextAtom) var searchText: String
            searchText = "Foo"
            try await expectEqual(cocktailState, .success(mock))
        }
    }

    @MainActor
    func testAddToFavorite() async throws {
        await TestStore { store in
            @CaptureAtomValue(favoritesManagerAtom) var favoriteManager: FavoritesManager
            favoriteManager.add(.mock)
            XCTAssertEqual(favoriteManager.favorites, [.mock])
            favoriteManager.remove(.mock)
            XCTAssert(favoriteManager.favorites.isEmpty)
        }
    }
}
