import SwiftUI

struct CocktailImageView: View {
    enum Size {
        case regular
        case thumbnail
    }
    let imageSource: String?
    let size: Size
    
    var body: some View {
        if let imgSource = imageSource, let url = URL(string: imgSource) {
            AsyncImage(
                url: url,
                content: { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(maxWidth: size == .regular ? 300 : 50, maxHeight: size == .regular ? 300 : 50)
                },
                placeholder: {
                    ProgressView()
                }
            )
        } else {
            Text("🍹")
                .font(size == .regular ? .system(size: 90) : .system(size: 20))
        }
    }
}
struct CocktailImageView_Previews: PreviewProvider {
    static var previews: some View {
        CocktailImageView(imageSource: nil, size: .regular)
    }
}
