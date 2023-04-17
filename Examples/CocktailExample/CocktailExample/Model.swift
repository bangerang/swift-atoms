import Foundation

struct Drinks: Codable {
    let drinks: [Cocktail]
}
struct Cocktail: Codable, Hashable, Identifiable {
    var id: String {
        idDrink
    }
    let idDrink: String
    let strDrink: String
    let strInstructions: String
    let strImageSource: String?
    let strDrinkThumb: String?
}

extension Cocktail {
    static var mock: Cocktail {
        .init(idDrink: "1",
              strDrink: "Margarita",
              strInstructions: "Do things",
              strImageSource: nil,
              strDrinkThumb: nil)
    }
}

struct CocktailAPI {
    static func searchCocktail(_ query: String) async throws -> [Cocktail] {
        guard let urlEncoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            fatalError()
        }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://www.thecocktaildb.com/api/json/v1/1/search.php?s=\(urlEncoded)")!)
        let decoder = JSONDecoder()
        return try decoder.decode(Drinks.self, from: data).drinks
    }
}

let cocktailAPI = CocktailAPI()

struct CocktailService {
    var search: (String) async throws -> [Cocktail]
}

class FavoritesManager: ObservableObject {
    @Published var favorites: [Cocktail] = []
    
    init(favorites: [Cocktail] = []) {
        self.favorites = favorites
    }
    
    func isFavorite(_ cocktail: Cocktail) -> Bool {
        return favorites.contains(where: { $0.id == cocktail.id})
    }
    func add(_ cocktail: Cocktail) {
        favorites.append(cocktail)
    }
    func remove(_ cocktail: Cocktail) {
        favorites.removeAll(where: { $0.id == cocktail.id })
    }
}
