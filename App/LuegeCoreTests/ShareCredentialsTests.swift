import Testing
@testable import Luege

@Suite("ShareCredentials Tests")
struct ShareCredentialsTests {

    @Test("Guest credentials have expected values")
    func testGuestCredentials() {
        let guest = ShareCredentials.guest
        #expect(guest.username == "guest")
        #expect(guest.password == "guest")
    }

    @Test("Custom credentials are stored correctly")
    func testCustomCredentials() {
        let creds = ShareCredentials(username: "admin", password: "secret123")
        #expect(creds.username == "admin")
        #expect(creds.password == "secret123")
    }

    @Test("Credentials are Hashable")
    func testHashable() {
        let creds1 = ShareCredentials(username: "user", password: "pass")
        let creds2 = ShareCredentials(username: "user", password: "pass")
        let creds3 = ShareCredentials(username: "user", password: "different")

        #expect(creds1 == creds2)
        #expect(creds1 != creds3)
        #expect(creds1.hashValue == creds2.hashValue)
    }

    @Test("Credentials can be used in Set")
    func testSetUsage() {
        var credSet: Set<ShareCredentials> = []
        let creds1 = ShareCredentials(username: "user1", password: "pass1")
        let creds2 = ShareCredentials(username: "user2", password: "pass2")
        let creds1Duplicate = ShareCredentials(username: "user1", password: "pass1")

        credSet.insert(creds1)
        credSet.insert(creds2)
        credSet.insert(creds1Duplicate)

        #expect(credSet.count == 2)
    }
}
