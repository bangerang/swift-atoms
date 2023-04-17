import Foundation
import Atoms

let usernameAtom = Atom("")

let passwordAtom = Atom("")

let usernameIsValidAtom = DerivedAtom {
    @UseAtomValue(usernameAtom) var username;
    
    return username.count >= 5
}

let passwordIsValidAtom = DerivedAtom {
    @UseAtomValue(passwordAtom) var password;
    guard
        let regex = try? Regex(#"^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$"#),
        let match = try? regex.firstMatch(in: password)
    else {
        return false
    }
    return !match.isEmpty
}

let signupIsValidAtom = DerivedAtom {
    @UseAtomValue(usernameIsValidAtom) var usernameValid
    @UseAtomValue(passwordIsValidAtom) var passwordValid
    return usernameValid && passwordValid
}

let signedInStateAtom = Atom<AsyncState<Void>?>(nil)
