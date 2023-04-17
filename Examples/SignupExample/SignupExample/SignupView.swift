import SwiftUI
import Atoms
import RegexBuilder
import Combine

struct SignupView: View {
    @UseAtom(usernameAtom) var username
    @UseAtom(passwordAtom) var password
    @UseAtom(signedInStateAtom) var signupState
    @UseAtomValue(signupIsValidAtom) var signupIsValid
    
    var body: some View {
        NavigationStack {
            Group {
                if let signupState {
                    switch signupState {
                    case .loading:
                        ProgressView()
                    case .success:
                        Text("Success")
                    case .failure:
                        Text("Failure")
                    }
                } else {
                    Form {
                        Section {
                            TextField("Username", text: $username)
                        } footer: {
                            Text("At least 5 characters.")
                        }
                        Section {
                            SecureField("Password", text: $password)
                        } footer: {
                            Text("One uppercase letter, one lowercase letter, one number, and a minimum length of 8 characters.")
                        }
                        
                        Section {
                            Button("Sign up") {
                                Task {
                                    try await performSignUp()
                                }
                            }.disabled(!signupIsValid)
                        }
                    }
                }
            }
            .navigationTitle("Sign up")
        }
    }
    
    func performSignUp() async throws {
        signupState = .loading
        try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
        signupState = .success(())
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
            .inject(usernameAtom) {
                "johndoe"
            }
            .inject(passwordAtom) {
                "passw0rD"
            }
    }
}

