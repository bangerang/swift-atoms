import XCTest
@testable import SignupExample
import Atoms

final class SignupExampleTests: XCTestCase {
    @MainActor
    func testSignup() async throws {
        try await TestStore { store in
            @CaptureAtom(usernameAtom) var username: String
            @CaptureAtom(passwordAtom) var password: String
            @CaptureAtomValue(signupIsValidAtom) var signupIsValid: Bool
            XCTAssert(!signupIsValid)
            username = "johndoe"
            password = "passw0rD"
            try await expect(signupIsValid)
        }
    }
}
