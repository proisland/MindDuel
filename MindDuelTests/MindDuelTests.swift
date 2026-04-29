import XCTest
@testable import MindDuel

final class MindDuelTests: XCTestCase {

    func testUsernameValidation() {
        let valid = ["alice", "bob_99", "User123", "abc"]
        let invalid = ["ab", "", "a very long username that exceeds twenty", "user name", "user@name"]

        for name in valid {
            XCTAssertTrue(isValidUsername(name), "\(name) should be valid")
        }
        for name in invalid {
            XCTAssertFalse(isValidUsername(name), "\(name) should be invalid")
        }
    }

    private func isValidUsername(_ username: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return (3...20).contains(username.count)
            && username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
